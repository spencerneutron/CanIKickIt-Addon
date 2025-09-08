local NS = select(2, ...)

local pool = {}              -- guid -> frame
local assignments = {}       -- guid -> { {player, spellID, ts}, ... }

function NS.Nameplates_Init() 
    -- nothing to do here; frames are created on demand
end

local function GetPlate(unit)
  return C_NamePlate.GetNamePlateForUnit(unit)
end

-- local store for assignments
function NS.Assignments_Add(guid, spellID, player, ts)
  assignments[guid] = assignments[guid] or {}
  table.insert(assignments[guid], { player = player, spellID = spellID, ts = ts })
  NS.Nameplates_Refresh(guid)
end

function NS.Assignments_OnRemoteAssign(guid, spellID, player, ts)
  NS.Assignments_Add(guid, tonumber(spellID), player, tonumber(ts))
end

function NS.Nameplates_OnAdded(unit)
  local guid = UnitGUID(unit)
  if not guid then return end
  local plate = GetPlate(unit)
  if not plate then return end

  local f = CreateFrame("Frame", nil, plate)
  f:SetPoint("LEFT", plate.UnitFrame or plate, "RIGHT", 6, 0)
  f:SetSize(1,1)
  f.icons = {}
  pool[guid] = f

  NS.Nameplates_Refresh(guid)
end

function NS.Nameplates_OnRemoved(unit)
  local guid = UnitGUID(unit)
  local f = pool[guid]
  if not f then return end
  for _, btn in ipairs(f.icons) do
    btn:Hide()
    btn:SetParent(nil)
  end
  pool[guid] = nil
end

function NS.Nameplates_OnInterruptCast(guid, player, spellID)
  -- when someone actually casts, we could bump their icon highlight; optional
  NS.Nameplates_Refresh(guid)
end

function NS.Nameplates_OnCooldownUpdate(player, spellID, readyAt)
  -- called by Cooldowns when CD changes; refresh all strips containing this player/spell
  for guid, list in pairs(assignments) do
    for _, a in ipairs(list) do
      if a.player == player and a.spellID == spellID then
        NS.Nameplates_Refresh(guid)
      end
    end
  end
end

local function AcquireIcon(parent, index)
  local btn = parent.icons[index]
  if not btn then
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

local function SpellIcon(spellID)
  -- safe retrieval of a spell icon: prefer global GetSpellInfo, then C_Spell.GetSpellInfo, then GetSpellTexture
  if type(GetSpellInfo) == "function" then
    local _, _, icon = GetSpellInfo(spellID)
    return icon
  end

  if type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function" then
    local _, _, icon = C_Spell.GetSpellInfo(spellID)
    return icon
  end

  if type(GetSpellTexture) == "function" then
    return GetSpellTexture(spellID)
  end

  return nil
end

function NS.Nameplates_Refresh(guid)
  local f = pool[guid]
  if not f then return end
  local list = assignments[guid] or {}
  table.sort(list, function(a,b) return a.ts < b.ts end)

  local idx = 1
  for _, a in ipairs(list) do
    local btn = AcquireIcon(f, idx)
    btn.icon:SetTexture(SpellIcon(a.spellID))

    local remain = NS.Cooldowns_Get(a.player, a.spellID)
    if remain > 0 then
      btn.cd:SetCooldown(GetTime() + remain - remain, remain) -- start now, set duration
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
  -- iterate visible nameplates and call existing refresh logic
  for _, plate in pairs(C_NamePlate.GetNamePlates() or {}) do
    local unit = plate.namePlateUnitToken
    if unit then
      local guid = UnitGUID(unit)
      if guid then NS.Nameplates_Refresh(guid) end
    end
  end
end
