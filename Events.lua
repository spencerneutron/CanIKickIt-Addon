local NS = select(2, ...)
local f

-- Lightweight cache: petGUID -> ownerName
local petOwnerCache = {}

local function BuildPetOwnerCache()
  wipe(petOwnerCache)
  -- player pet
  local pg = UnitGUID("pet")
  if pg then petOwnerCache[pg] = UnitName("player") end
  -- raid pets
  if IsInRaid() then
    for i = 1, 40 do
      local unit = "raid" .. i
      if UnitExists(unit) then
        local petUnit = unit .. "pet"
        local pGuid = UnitGUID(petUnit)
        if pGuid then petOwnerCache[pGuid] = UnitName(unit) end
      else
        break
      end
    end
  -- party pets
  elseif IsInGroup() then
    for i = 1, 4 do
      local unit = "party" .. i
      if UnitExists(unit) then
        local petUnit = unit .. "pet"
        local pGuid = UnitGUID(petUnit)
        if pGuid then petOwnerCache[pGuid] = UnitName(unit) end
      else
        break
      end
    end
  end
end

local function ResolvePetOwner(srcGUID)
  if not srcGUID then return nil end
  return petOwnerCache[srcGUID]
end

function NS.Events_Init()
  if f then return end  -- idempotent
  f = CreateFrame("Frame")
  f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
  f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  f:RegisterEvent("GROUP_ROSTER_UPDATE")
  f:RegisterEvent("UNIT_PET")
  f:SetScript("OnEvent", function(_, evt, ...)
    if evt == "NAME_PLATE_UNIT_ADDED" then
      NS.Nameplates_OnAdded(...)
    elseif evt == "NAME_PLATE_UNIT_REMOVED" then
      NS.Nameplates_OnRemoved(...)
    elseif evt == "COMBAT_LOG_EVENT_UNFILTERED" then
      NS.OnCombatLog(CombatLogGetCurrentEventInfo())
    elseif evt == "GROUP_ROSTER_UPDATE" or evt == "UNIT_PET" then
      -- refresh pet-owner mapping for quick lookup
      BuildPetOwnerCache()
    end
  end)

  -- build initial cache
  BuildPetOwnerCache()
end

-- Combat log: infer interrupts & start cooldowns
function NS.OnCombatLog(...)
  local timestamp, sub, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, dstGUID, dstName, dstFlags, dstRaidFlags, spellID = ...
  if sub == "SPELL_CAST_SUCCESS" and dstGUID and spellID then
    -- canonicalize spell id for merged/alias cases
    local canon = NS.ResolveSpellID(spellID) or spellID
    -- cheap pre-filter
    if not NS.IsInterruptSpell(canon) then return end

    -- resolve source player (handle pet casts)
    local actor = srcName
    if not actor or actor == "" then
      local owner = ResolvePetOwner(srcGUID)
      if owner then actor = owner end
    else
      -- also handle known pet GUID mapping
      local owner = ResolvePetOwner(srcGUID)
      if owner then actor = owner end
    end

    local cd = NS.GetBaseCD(canon)       -- Cooldowns.lua can adjust per class/spec if needed
    NS.Cooldowns_Start(actor, canon, cd)
    NS.Comm_SendCD(canon, actor or "unknown", NS.Now(), cd)
    -- If dstGUID is hostile mob, update strip ordering
    if dstGUID then NS.Nameplates_OnInterruptCast(dstGUID, actor, canon) end
  end
end
