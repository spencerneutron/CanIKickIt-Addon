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

-- Reconcile local player's interrupt cooldowns with the game's cooldowns
local cooldownsReconcileScheduled = false
local cooldownsReconcileDelay = 0.25 -- 250ms debounce
local cooldownsReconcileTolerance = 0.5 -- seconds

local function ReconcileLocalCooldowns()
  cooldownsReconcileScheduled = false
  NS:Log("ReconcileLocalCooldowns: start")
  local playerName = UnitName("player")
  local watched = NS.GetPlayerInterrupts and NS.GetPlayerInterrupts() or {}

  for _, entry in ipairs(watched) do
    local sid = tonumber(NS.ResolveSpellID(entry.spellID) or entry.spellID)
    if not sid then
      NS:Log("ReconcileLocalCooldowns: bad sid for entry", tostring(entry.spellID))
    else
      -- Use only C_Spell.GetSpellCooldown per runtime contract
      local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(sid) or nil

      if not info then
        NS:Log("ReconcileLocalCooldowns: no cooldown info for", sid)
      else
        -- info is a table: { startTime, duration, isEnabled, modRate, activeCategory }
        local st = info.startTime
        local dur = info.duration
        local enabled = info.isEnabled

        if st and dur and enabled and dur > 0 then
          local readyAt = st + dur
          local _, _, storedReady = NS.Cooldowns_GetInfo(playerName, sid)
          if not storedReady or math.abs((storedReady or 0) - readyAt) > cooldownsReconcileTolerance then
            NS:Log("ReconcileLocalCooldowns: update", sid, "st=", st, "dur=", dur, "readyAt=", readyAt)
            -- apply authoritative API values locally
            NS.Cooldowns_OnRemoteCD(sid, playerName, st, dur)
            -- broadcast only if syncing enabled
            if NS.DB and NS.DB.syncMode then
              NS:Log("ReconcileLocalCooldowns: broadcast", sid)
              NS.Comm_SendCD(sid, playerName, st, dur)
            end
          else
            NS:Log("ReconcileLocalCooldowns: no meaningful change for", sid)
          end
        else
          NS:Log("ReconcileLocalCooldowns: spell ready or not enabled", sid, "dur=", tostring(dur), "enabled=", tostring(enabled))
        end
      end
    end
  end

  NS:Log("ReconcileLocalCooldowns: done")
end

local function ScheduleReconcileLocalCooldowns()
  if cooldownsReconcileScheduled then return end
  cooldownsReconcileScheduled = true
  if C_Timer and C_Timer.After then
    C_Timer.After(cooldownsReconcileDelay, ReconcileLocalCooldowns)
  else
    ReconcileLocalCooldowns()
  end
end

function NS.Events_Init()
  if f then return end  -- idempotent
  f = CreateFrame("Frame")
  f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
  f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  f:RegisterEvent("GROUP_ROSTER_UPDATE")
  f:RegisterEvent("UNIT_PET")
  f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
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
    elseif evt == "SPELL_UPDATE_COOLDOWN" then
      ScheduleReconcileLocalCooldowns()
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

    -- If this is the local player (or their pet), create a local 'cast' assignment and broadcast
    local me = UnitName("player")
    if actor == me then
      NS.Assignments_Add(dstGUID, canon, actor, NS.Now(), "cast")
      NS.Comm_SendAssign(dstGUID, canon, actor, NS.Now(), "cast")
    end

    NS.Comm_SendCD(canon, actor or "unknown", NS.Now(), cd)
    -- If dstGUID is hostile mob, update strip ordering
    if dstGUID then NS.Nameplates_OnInterruptCast(dstGUID, actor, canon) end
  end
end
