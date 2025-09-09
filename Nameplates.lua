-- luacheck: globals CreateFrame GetSpellTexture UnitGUID GetTime C_NamePlate C_Spell C_Timer SLASH_CIKI_TEX1 SlashCmdList

local NS = select(2, ...)
NS:Log("Nameplates module loaded")

-- Local aliases (lint + perf)
local CreateFrame     = CreateFrame
local GetSpellTexture = GetSpellTexture
local UnitGUID        = UnitGUID
local GetTime         = GetTime
local C_NamePlate     = C_NamePlate
local C_Spell         = C_Spell
local C_Timer         = C_Timer

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------
local pool = {}                -- guid -> strip frame
local assignments = {}         -- guid -> { {player, spellID, ts}, ... }
local pendingSpellIcons = {}   -- spellID -> { guidSet = { [guid] = true } }
local dirty = {}               -- guid -> true (needs refresh)
local flushScheduled = false   -- batch refresh flag
local pendingTimerScheduled = false -- async icon polling flag

local QUESTION_MARK_FILEID = 134400  -- Interface\Icons\INV_Misc_QuestionMark

-- -----------------------------------------------------------------------------
-- Async spell icon resolution (event + light polling fallback)
-- -----------------------------------------------------------------------------
local function ProcessPendingSpellIcons()
  NS:Log("ProcessPendingSpellIcons start")
  local checked = 0
  for spellID, bucket in pairs(pendingSpellIcons) do
    checked = checked + 1
    local icon
    if C_Spell and C_Spell.GetSpellInfo then
      local info = C_Spell.GetSpellInfo(spellID)
      if info and info.iconID then icon = info.iconID end
    elseif GetSpellTexture then
      icon = GetSpellTexture(spellID)
    end
    if icon then
      NS:Log("ProcessPendingSpellIcons resolved", spellID, tostring(icon))
      for guid in pairs(bucket.guidSet) do
        NS.Nameplates_Refresh(guid)
      end
      pendingSpellIcons[spellID] = nil
    end
  end
  NS:Log("ProcessPendingSpellIcons done, checked", checked)
  pendingTimerScheduled = false
end

function NS.Nameplates_Init()
  NS:Log("Nameplates_Init called")
  if not NS._spellIconEvt then
    local iconEvt = CreateFrame("Frame")
    iconEvt:RegisterEvent("SPELL_DATA_LOAD_RESULT")
    iconEvt:SetScript("OnEvent", function(_, _, spellID, success)
      if not success then return end
      local bucket = pendingSpellIcons[spellID]
      if not bucket then return end
      for guid in pairs(bucket.guidSet) do
        NS.Nameplates_Refresh(guid)
      end
      pendingSpellIcons[spellID] = nil
    end)
    NS._spellIconEvt = iconEvt
  end
end

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------
local function GetPlate(unit)
  return C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
end

local function scheduleFlush()
  if flushScheduled then return end
  flushScheduled = true
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      flushScheduled = false
      for g in pairs(dirty) do
        dirty[g] = nil
        NS.Nameplates_Refresh(g)
      end
    end)
  else
    for g in pairs(dirty) do
      dirty[g] = nil
      NS.Nameplates_Refresh(g)
    end
    flushScheduled = false
  end
end

-- -----------------------------------------------------------------------------
-- Assignment management
-- -----------------------------------------------------------------------------
function NS.Assignments_Add(guid, spellID, player, ts, source)
  NS:Log("Assignments_Add", guid, spellID, player, ts, source)
  source = source or "cast"
  -- If this player already has a macro-locked assignment, ignore non-macro updates
  for g, list in pairs(assignments) do
    for i = #list, 1, -1 do
      if list[i].player == player and list[i].source == "macro" and source ~= "macro" then
        NS:Log("Assignments_Add: player has macro-locked assignment; ignoring non-macro update", player)
        return
      end
    end
  end

  -- Purge any previous assignments for this player
  for g, list in pairs(assignments) do
    for i = #list, 1, -1 do
      if list[i].player == player then
        table.remove(list, i)
        dirty[g] = true
      end
    end
  end
  assignments[guid] = assignments[guid] or {}
  table.insert(assignments[guid], { player = player, spellID = spellID, ts = ts, source = source })
  dirty[guid] = true
  scheduleFlush()
end

function NS.Assignments_OnRemoteAssign(guid, spellID, player, ts, source)
  NS:Log("Assignments_OnRemoteAssign", guid, spellID, player, ts, source)
  NS.Assignments_Add(guid, tonumber(spellID), player, tonumber(ts), source or "remote")
end

-- Optional: clear transient state (used by Core.ClearTransientState)
function NS.Assignments_Clear()
  wipe(assignments)
  for guid, f in pairs(pool) do
    for _, btn in ipairs(f.icons or {}) do
      btn:Hide()
      btn:SetParent(nil)
    end
    pool[guid] = nil
  end
end

-- -----------------------------------------------------------------------------
-- Nameplate lifecycle
-- -----------------------------------------------------------------------------
function NS.Nameplates_OnAdded(unit)
  local guid = UnitGUID(unit)
  NS:Log("Nameplates_OnAdded", unit, guid)
  if not guid then return end

  -- quick exit for non-hostile units (avoid expensive plate lookups)
  if not UnitCanAttack("player", unit) then
    NS:Log("Nameplates_OnAdded: skipping non-hostile unit", unit)
    return
  end

  local plate = GetPlate(unit)
  if not plate then
    NS:Log("Nameplates_OnAdded no plate for unit", unit)
    return
  end

  -- IMPORTANT: parent to the plate ROOT (not UnitFrame) to avoid 3rd-party clipping/fading
  local parentAnchor = plate.UnitFrame or plate
  local f = CreateFrame("Frame", nil, plate)  -- parent = plate (root)
  if (NS.DB and NS.DB.iconAnchor) == "left" then
    f:SetPoint("RIGHT", parentAnchor, "LEFT", -6, 0)
  else
    f:SetPoint("LEFT", parentAnchor, "RIGHT", 6, 0)
  end
  f:SetSize(1, 1)
  f.icons = {}

  -- keep visible above nameplate visuals and immune to parent alpha/scale games
  f:SetFrameStrata("HIGH")
  f:SetFrameLevel((plate:GetFrameLevel() or 0) + 100)
  if f.SetIgnoreParentAlpha then f:SetIgnoreParentAlpha(true) end
  if f.SetIgnoreParentScale then f:SetIgnoreParentScale(true) end

  pool[guid] = f
  NS.Nameplates_Refresh(guid)
end

function NS.Nameplates_OnRemoved(unit)
  local guid = UnitGUID(unit)
  NS:Log("Nameplates_OnRemoved", unit, guid)

  -- if we have no visuals for this guid and the unit is non-hostile, skip quickly
  local f = pool[guid]
  if not f and not UnitCanAttack("player", unit) then
    NS:Log("Nameplates_OnRemoved: skipping non-hostile/unit without pool", unit)
    return
  end

  if not f then return end
  for _, btn in ipairs(f.icons) do
    btn:Hide()
    btn:SetParent(nil)
  end
  pool[guid] = nil
end

function NS.Nameplates_OnInterruptCast(guid, player, spellID)
  NS:Log("Nameplates_OnInterruptCast", guid, player, spellID)
  NS.Nameplates_Refresh(guid)
end

function NS.Nameplates_NotifyCooldownChanged(player, spellID)
  for guid, list in pairs(assignments) do
    for i = 1, #list do
      local a = list[i]
      if a.player == player and a.spellID == spellID then
        dirty[guid] = true
        break
      end
    end
  end
  scheduleFlush()
end

-- -----------------------------------------------------------------------------
-- UI construction
-- -----------------------------------------------------------------------------
local function AcquireIcon(parent, index)
  local btn = parent.icons[index]
  if not btn then
    NS:Log("AcquireIcon creating", index)
    btn = CreateFrame("Button", nil, parent)
    btn:SetSize(NS.DB.iconSize or 18, NS.DB.iconSize or 18)
    btn:EnableMouse(false)

    -- layer once above plate content
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel((parent:GetFrameLevel() or 0) + 1)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(true)
    btn.icon:SetDrawLayer("ARTWORK", 1)
    btn.icon:SetVertexColor(1, 1, 1, 1)

    btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cd:SetAllPoints(true)
    btn.cd:SetAlpha(1)

    -- lock indicator for macro-assigned intents
    btn.lock = btn:CreateTexture(nil, "OVERLAY")
    btn.lock:SetSize(8, 8)
    btn.lock:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    
    -- use a built-in lock icon file id if available, fallback to white square
    local lockTex = 136710 -- UI-Panel-Button-Play (approx); it's fine as a placeholder
    btn.lock:SetTexture(lockTex)
    btn.lock:Hide()

    parent.icons[index] = btn
  else
    NS:Log("AcquireIcon reuse", index)
  end

  btn:ClearAllPoints()
  local anchor = (NS.DB and NS.DB.iconAnchor) or "right"
  local spacing = NS.DB.iconSpacing or 2

  if anchor == "left" then
    if index == 1 then
      btn:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    else
      btn:SetPoint("RIGHT", parent.icons[index - 1], "LEFT", -spacing, 0)
    end
  else
    if index == 1 then
      btn:SetPoint("LEFT", parent, "LEFT", 0, 0)
    else
      btn:SetPoint("LEFT", parent.icons[index - 1], "RIGHT", spacing, 0)
    end
  end
  btn:Show()
  btn:SetAlpha(1)
  return btn
end

local function SpellIcon(spellID, guid)
  spellID = NS.ResolveSpellID(spellID) or spellID
  -- 1) Preferred: C_Spell.GetSpellInfo() table with iconID
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellID)
    if info and info.iconID then
      return info.iconID
    end
  end

  -- 2) Fallback: GetSpellTexture
  if GetSpellTexture then
    local icon = GetSpellTexture(spellID)
    if icon then return icon end
  end

  -- 3) Async load then refresh
  if C_Spell and C_Spell.RequestLoadSpellData then
    C_Spell.RequestLoadSpellData(spellID)
    local bucket = pendingSpellIcons[spellID]
    if not bucket then
      bucket = { guidSet = {} }
      pendingSpellIcons[spellID] = bucket
    end
    if guid then bucket.guidSet[guid] = true end

    if not pendingTimerScheduled and C_Timer and C_Timer.After then
      pendingTimerScheduled = true
      C_Timer.After(0.5, ProcessPendingSpellIcons)
    end
  end

  return QUESTION_MARK_FILEID
end

-- -----------------------------------------------------------------------------
-- Refresh
-- -----------------------------------------------------------------------------
function NS.Nameplates_Refresh(guid)
  local f = pool[guid]
  if not f then return end

  local list = assignments[guid] or {}
  table.sort(list, function(a, b)
    -- primary: ascending base cooldown (unknown = treat as large)
    local aCD = (NS.GetBaseCD and NS.GetBaseCD(a.spellID)) or math.huge
    local bCD = (NS.GetBaseCD and NS.GetBaseCD(b.spellID)) or math.huge
    if aCD ~= bCD then return aCD < bCD end
    -- tie-break: lower numeric spellID
    local aID = tonumber(a.spellID) or math.huge
    local bID = tonumber(b.spellID) or math.huge
    if aID ~= bID then return aID < bID end
    -- final tie-break: received order (timestamp)
    return (a.ts or 0) < (b.ts or 0)
  end)

  local idx = 1
  for _, a in ipairs(list) do
    local btn = AcquireIcon(f, idx)

    -- icon
    local iconTex = SpellIcon(a.spellID, guid)
    btn.icon:SetTexture(iconTex)
    btn.icon:Show()

    -- lock indicator for macro assignments
    if a.source == "macro" then
      if btn.lock then btn.lock:Show() end
    else
      if btn.lock then btn.lock:Hide() end
    end

    -- cooldown (set once; CooldownFrame animates itself)
    local s, d = NS.Cooldowns_GetInfo(a.player, a.spellID)
    if s and d and d > 0 then
      btn.cd:SetCooldown(s, d)
    else
      btn.cd:Clear()
    end

    idx = idx + 1
  end

  -- hide unused icons
  for i = idx, #f.icons do
    if f.icons[i] then
      f.icons[i]:Hide()
    end
  end
end

function NS.Nameplates_RefreshAll()
  local plates = (C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()) or {}
  for _, plate in pairs(plates) do
    local unit = plate.namePlateUnitToken
    if unit then
      local guid = UnitGUID(unit)
      if guid then NS.Nameplates_Refresh(guid) end
    end
  end
end

-- -----------------------------------------------------------------------------
-- Slash test: draw a test icon on a plate (bypasses addon flow)
-- -----------------------------------------------------------------------------
SLASH_CIKI_TEX1 = "/cikitex"
SlashCmdList.CIKI_TEX = function(msg)
  local unit = (msg and msg ~= "") and msg or "target"
  local plate = GetPlate(unit)
  if not plate then
    print("CIKI: no plate for", unit)
    return
  end
  local parentAnchor = plate.UnitFrame or plate
  local f = CreateFrame("Frame", nil, plate) -- parent root
  f:SetPoint("LEFT", parentAnchor, "RIGHT", 6, 0)
  f:SetSize(24, 24)
  f:SetFrameStrata("HIGH")
  f:SetFrameLevel((plate:GetFrameLevel() or 0) + 100)
  if f.SetIgnoreParentAlpha then f:SetIgnoreParentAlpha(true) end
  if f.SetIgnoreParentScale then f:SetIgnoreParentScale(true) end
  local t = f:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints(true)
  t:SetTexture(QUESTION_MARK_FILEID)
  print("CIKI: drew test icon on", unit)
end

SLASH_CIKI_ANCHOR1 = "/cikianchor"
SlashCmdList.CIKI_ANCHOR = function()
  NS.DB.iconAnchor = (NS.DB.iconAnchor == "left") and "right" or "left"
  print("CIKI: icon anchor set to", NS.DB.iconAnchor)
  NS.Nameplates_RefreshAll()
end
