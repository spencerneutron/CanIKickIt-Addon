local NS = select(2, ...)

local pool = {}              -- guid -> frame
local assignments = {}       -- guid -> { {player, spellID, ts}, ... }
local pendingSpellIcons = {} -- spellID -> { guidSet = { [guid]=true } }
local QUESTION_MARK_FILEID = 134400  -- INV_Misc_QuestionMark

local dirty = {}             -- guid -> true
local flushScheduled = false


function NS.Nameplates_Init()
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

local function GetPlate(unit)
  return C_NamePlate.GetNamePlateForUnit(unit)
end

-- local store for assignments
function NS.Assignments_Add(guid, spellID, player, ts)
  NS:Log("Assignments_Add", guid, spellID, player, ts)
  assignments[guid] = assignments[guid] or {}
    table.insert(assignments[guid], { player = player, spellID = spellID, ts = ts })
    dirty[guid] = true
    if not flushScheduled then
    flushScheduled = true
    C_Timer.After(0, function()
        flushScheduled = false
        for g in pairs(dirty) do dirty[g] = nil; NS.Nameplates_Refresh(g) end
    end)
    end
end

function NS.Assignments_OnRemoteAssign(guid, spellID, player, ts)
  NS:Log("Assignments_OnRemoteAssign", guid, spellID, player, ts)
  NS.Assignments_Add(guid, tonumber(spellID), player, tonumber(ts))
end

function NS.Nameplates_OnAdded(unit)
  local guid = UnitGUID(unit)
  NS:Log("Nameplates_OnAdded", unit, guid)
  if not guid then return end
  local plate = GetPlate(unit)
  if not plate then
    NS:Log("Nameplates_OnAdded no plate for unit", unit)
    return end

  local f = CreateFrame("Frame", nil, plate)
  f:SetPoint("LEFT", plate.UnitFrame or plate, "RIGHT", 6, 0)
  f:SetSize(1,1)
  f.icons = {}
  pool[guid] = f

  NS.Nameplates_Refresh(guid)
end

function NS.Nameplates_OnRemoved(unit)
  local guid = UnitGUID(unit)
  NS:Log("Nameplates_OnRemoved", unit, guid)
  local f = pool[guid]
  if not f then return end
  for _, btn in ipairs(f.icons) do
    btn:Hide()
    btn:SetParent(nil)
  end
  pool[guid] = nil
end

function NS.Nameplates_OnInterruptCast(guid, player, spellID)
  NS:Log("Nameplates_OnInterruptCast", guid, player, spellID)
  -- when someone actually casts, we could bump their icon highlight; optional
  NS.Nameplates_Refresh(guid)
end

function NS.Nameplates_NotifyCooldownChanged(player, spellID)
  -- Mark all GUIDs containing (player,spellID) as dirty; quick scan is fine
  for guid, list in pairs(assignments) do
    for i = 1, #list do
      local a = list[i]
      if a.player == player and a.spellID == spellID then
        dirty[guid] = true
        break
      end
    end
  end
  -- Batch once per frame
  if not flushScheduled then
    flushScheduled = true
    C_Timer.After(0, function()
      flushScheduled = false
      for guid in pairs(dirty) do
        dirty[guid] = nil
        NS.Nameplates_Refresh(guid)
      end
    end)
  end
end

local function AcquireIcon(parent, index)
  local btn = parent.icons[index]
  if not btn then
    NS:Log("AcquireIcon creating", index)
    btn = CreateFrame("Button", nil, parent)
    btn:SetSize(NS.DB.iconSize, NS.DB.iconSize)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(true)
    btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cd:SetAllPoints(true)
    parent.icons[index] = btn
  end
  btn:ClearAllPoints()
  if index == 1 then
    btn:SetPoint("LEFT", parent, "LEFT", 0, 0)
  else
    btn:SetPoint("LEFT", parent.icons[index-1], "RIGHT", NS.DB.iconSpacing, 0)
  end
  btn:Show()
  return btn
end

local function SpellIcon(spellID, guid)
  -- 1) C_Spell.GetSpellInfo returns a table (info.name, info.iconID, ...)
  if type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function" then
    local info = C_Spell.GetSpellInfo(spellID)
    if info and info.iconID then
      NS:Log("SpellIcon via C_Spell.GetSpellInfo", spellID, info.iconID)
      return info.iconID
    end
  end

  -- 2) Fallback: GetSpellTexture still exists on mainline
  if type(GetSpellTexture) == "function" then
    local icon = GetSpellTexture(spellID)
    if icon then
      NS:Log("SpellIcon via GetSpellTexture", spellID, tostring(icon))
      return icon
    end
  end

  -- 3) Request async load; we'll refresh when it completes
  if type(C_Spell) == "table" and type(C_Spell.RequestLoadSpellData) == "function" then
    NS:Log("SpellIcon requesting load for", spellID, "for guid", guid)
    C_Spell.RequestLoadSpellData(spellID)
    local bucket = pendingSpellIcons[spellID]
    if not bucket then
      bucket = { guidSet = {} }
      pendingSpellIcons[spellID] = bucket
    end
    if guid then bucket.guidSet[guid] = true end
  end

  -- 4) Return a placeholder so something renders now
  NS:Log("SpellIcon returning placeholder for", spellID)
  return QUESTION_MARK_FILEID
end

function NS.Nameplates_Refresh(guid)
  NS:Log("Nameplates_Refresh", guid)
  local f = pool[guid]
  if not f then
    NS:Log("Nameplates_Refresh no frame for", guid)
    return end
  local list = assignments[guid] or {}
  table.sort(list, function(a,b) return a.ts < b.ts end)

  local idx = 1
  for _, a in ipairs(list) do
    NS:Log("Nameplates_Refresh item", idx, a.player, a.spellID, a.ts)
    local btn = AcquireIcon(f, idx)
    local iconTex = SpellIcon(a.spellID, guid)
    if iconTex then
      btn.icon:SetTexture(iconTex)
    else
      NS:Log("No icon texture for spell", a.spellID, "player", a.player)
      btn.icon:SetTexture(nil)
    end

    btn:EnableMouse(false)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(parent:GetFrameLevel() + 1)
    btn.icon:SetDrawLayer("ARTWORK", 1)

    -- inside the loop, after you set btn.icon:
    local s, d = NS.Cooldowns_GetInfo(a.player, a.spellID)
    if s and d and d > 0 then
    btn.cd:SetCooldown(s, d)   -- CooldownFrame animates itself
    else
    btn.cd:Clear()
    end

    idx = idx + 1
  end

  -- hide unused icons
  for i = idx, #f.icons do
    f.icons[i]:Hide()
  end
end

function NS.Nameplates_RefreshAll()
  NS:Log("Nameplates_RefreshAll")
  -- iterate visible nameplates and call existing refresh logic
  for _, plate in pairs(C_NamePlate.GetNamePlates() or {}) do
    local unit = plate.namePlateUnitToken
    if unit then
      local guid = UnitGUID(unit)
      if guid then NS.Nameplates_Refresh(guid) end
    end
  end
end
