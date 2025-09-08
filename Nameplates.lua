-- luacheck: globals CreateFrame GetSpellTexture UnitGUID GetTime C_NamePlate C_Spell C_Timer

local NS = select(2, ...)
NS:Log("Nameplates module loaded")

-- Local aliases for WoW API (helps linters and avoids global lookups)
local CreateFrame   = CreateFrame
local GetSpellTexture = GetSpellTexture
local UnitGUID      = UnitGUID
local GetTime       = GetTime
local C_NamePlate   = C_NamePlate
local C_Spell       = C_Spell
local C_Timer       = C_Timer

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------
local pool = {}                -- guid -> strip frame
local assignments = {}         -- guid -> { {player, spellID, ts}, ... }
local pendingSpellIcons = {}   -- spellID -> { guidSet = { [guid] = true } }
local dirty = {}               -- guid -> true (needs refresh)
local flushScheduled = false   -- batch refresh flag
local pendingTimerScheduled = false -- async icon polling flag

-- Use a fileID for the question mark; safer/faster than path string
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
        NS:Log("ProcessPendingSpellIcons refreshing guid", guid, "for spell", spellID)
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
  -- Event-based refresh for spell data loads
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
    -- Fallback (shouldn't happen in-game)
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
function NS.Assignments_Add(guid, spellID, player, ts)
  NS:Log("Assignments_Add", guid, spellID, player, ts)
  assignments[guid] = assignments[guid] or {}
  table.insert(assignments[guid], { player = player, spellID = spellID, ts = ts })
  dirty[guid] = true
  scheduleFlush()
end

function NS.Assignments_OnRemoteAssign(guid, spellID, player, ts)
  NS:Log("Assignments_OnRemoteAssign", guid, spellID, player, ts)
  NS.Assignments_Add(guid, tonumber(spellID), player, tonumber(ts))
end

-- -----------------------------------------------------------------------------
-- Nameplate lifecycle
-- -----------------------------------------------------------------------------
function NS.Nameplates_OnAdded(unit)
  local guid = UnitGUID(unit)
  NS:Log("Nameplates_OnAdded", unit, guid)
  if not guid then return end

  local plate = GetPlate(unit)
  if not plate then
    NS:Log("Nameplates_OnAdded no plate for unit", unit)
    return
  end

  local parent = plate.UnitFrame or plate
  local f = CreateFrame("Frame", nil, parent)
  f:SetPoint("LEFT", parent, "RIGHT", 6, 0)
  f:SetSize(1, 1)
  f.icons = {}

  -- Ensure strip renders above nameplate elements
  f:SetFrameStrata("TOOLTIP")
  f:SetFrameLevel((parent:GetFrameLevel() or 0) + 100)

  pool[guid] = f
  NS.Nameplates_Refresh(guid)
end

function NS.Nameplates_OnRemoved(unit)
  local guid = UnitGUID(unit)
  NS:Log("Nameplates_OnRemoved", unit, guid)
  local f = pool[guid]
  if not f then return end
  NS:Log("Nameplates_OnRemoved clearing", #f.icons, "icon slots for guid", guid)
  for _, btn in ipairs(f.icons) do
    btn:Hide()
    btn:SetParent(nil)
  end
  pool[guid] = nil
end

-- Optional visual nudge when an interrupt actually fires
function NS.Nameplates_OnInterruptCast(guid, player, spellID)
  NS:Log("Nameplates_OnInterruptCast", guid, player, spellID)
  NS.Nameplates_Refresh(guid)
end

-- Called by Cooldowns.lua when a player's CD state for a spell changes
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

    -- place above plate visuals (once)
    btn:SetFrameStrata("TOOLTIP")
    btn:SetFrameLevel((parent:GetFrameLevel() or 0) + 101)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(true)
    btn.icon:SetDrawLayer("ARTWORK", 1)
    btn.icon:SetVertexColor(1, 1, 1, 1)

    btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cd:SetAllPoints(true)
    btn.cd:SetAlpha(1)

    parent.icons[index] = btn
  else
    NS:Log("AcquireIcon reuse", index)
  end

  btn:ClearAllPoints()
  if index == 1 then
    btn:SetPoint("LEFT", parent, "LEFT", 0, 0)
  else
    btn:SetPoint("LEFT", parent.icons[index - 1], "RIGHT", NS.DB.iconSpacing or 2, 0)
  end
  btn:Show()
  return btn
end

local function SpellIcon(spellID, guid)
  -- 1) Preferred: C_Spell.GetSpellInfo() table with iconID
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellID)
    if info and info.iconID then
      NS:Log("SpellIcon via C_Spell.GetSpellInfo", spellID, info.iconID)
      return info.iconID
    end
  end

  -- 2) Fallback: GetSpellTexture
  if GetSpellTexture then
    local icon = GetSpellTexture(spellID)
    if icon then
      NS:Log("SpellIcon via GetSpellTexture", spellID, tostring(icon))
      return icon
    end
  end

  -- 3) Async load then refresh
  if C_Spell and C_Spell.RequestLoadSpellData then
    NS:Log("SpellIcon requesting load for", spellID, "for guid", guid)
    C_Spell.RequestLoadSpellData(spellID)
    local bucket = pendingSpellIcons[spellID]
    if not bucket then
      bucket = { guidSet = {} }
      pendingSpellIcons[spellID] = bucket
    end
    if guid then bucket.guidSet[guid] = true end

    -- Light polling as a backup in case the event misses
    if not pendingTimerScheduled and C_Timer and C_Timer.After then
      pendingTimerScheduled = true
      C_Timer.After(0.5, ProcessPendingSpellIcons)
      NS:Log("SpellIcon scheduled pending processor")
    end
  end

  -- 4) Placeholder (renders immediately so we can spot layering issues)
  NS:Log("SpellIcon returning placeholder for", spellID)
  return QUESTION_MARK_FILEID
end

-- -----------------------------------------------------------------------------
-- Refresh
-- -----------------------------------------------------------------------------
function NS.Nameplates_Refresh(guid)
  NS:Log("Nameplates_Refresh", guid)
  local f = pool[guid]
  if not f then
    NS:Log("Nameplates_Refresh no frame for", guid)
    return
  end

  local list = assignments[guid] or {}
  table.sort(list, function(a, b) return a.ts < b.ts end)

  local idx = 1
  for _, a in ipairs(list) do
    NS:Log("Nameplates_Refresh item", idx, a.player, a.spellID, a.ts)
    local btn = AcquireIcon(f, idx)

    -- icon texture
    local iconTex = SpellIcon(a.spellID, guid)
    if type(iconTex) == "number" or type(iconTex) == "string" then
      btn.icon:SetTexture(iconTex)
      if iconTex == QUESTION_MARK_FILEID then
        NS:Log("Nameplates_Refresh using placeholder for spell", a.spellID, "player", a.player)
      else
        NS:Log("Nameplates_Refresh using icon for spell", a.spellID, "texture", tostring(iconTex))
      end
    else
      NS:Log("No icon texture for spell", a.spellID, "player", a.player)
      btn.icon:SetTexture(QUESTION_MARK_FILEID)
    end
    btn.icon:Show()
    btn:SetAlpha(1)

    -- cooldown: set once with start/duration; CooldownFrame animates itself
    local s, d = NS.Cooldowns_GetInfo(a.player, a.spellID)
    if s and d and d > 0 then
      btn.cd:SetCooldown(s, d)
    else
      btn.cd:Clear()
    end

    idx = idx + 1
  end

  -- hide unused icons
  local hidden = 0
  for i = idx, #f.icons do
    if f.icons[i] then
      f.icons[i]:Hide()
      hidden = hidden + 1
    end
  end
  if hidden > 0 then
    NS:Log("Nameplates_Refresh hid unused icons", hidden, "for guid", guid)
  end
end

function NS.Nameplates_RefreshAll()
  NS:Log("Nameplates_RefreshAll")
  local plates = (C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()) or {}
  NS:Log("Nameplates_RefreshAll plate count", #plates)
  for _, plate in pairs(plates) do
    local unit = plate.namePlateUnitToken
    if unit then
      local guid = UnitGUID(unit)
      NS:Log("Nameplates_RefreshAll plate", unit, guid)
      if guid then NS.Nameplates_Refresh(guid) end
    end
  end
end
