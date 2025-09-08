local NS = select(2, ...)

local f = CreateFrame("Frame")

function NS.Events_Init()
  f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
  f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  f:SetScript("OnEvent", function(_, evt, ...)
    if evt == "NAME_PLATE_UNIT_ADDED" then
      NS.Nameplates_OnAdded(...)
    elseif evt == "NAME_PLATE_UNIT_REMOVED" then
      NS.Nameplates_OnRemoved(...)
    elseif evt == "COMBAT_LOG_EVENT_UNFILTERED" then
      NS.OnCombatLog(CombatLogGetCurrentEventInfo())
    end
  end)
end

-- Combat log: infer interrupts & start cooldowns
function NS.OnCombatLog(...)
  local _, sub, _, srcGUID, srcName, _, _, dstGUID, _, _, _, spellID = ...
  if sub == "SPELL_CAST_SUCCESS" then
    if NS.IsInterruptSpell(spellID) then
      local cd = NS.GetBaseCD(spellID, srcGUID)       -- Cooldowns.lua can adjust per class/spec if needed
      NS.Cooldowns_Start(srcName, spellID, cd)
      NS.Comm_SendCD(spellID, srcName or "unknown", NS.Now(), cd)
      -- If dstGUID is hostile mob, update strip ordering
      if dstGUID then NS.Nameplates_OnInterruptCast(dstGUID, srcName, spellID) end
    end
  end
end
