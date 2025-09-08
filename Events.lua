local addonName, CanIKickIt = ...
local Events = {}

local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName = CombatLogGetCurrentEventInfo()
        if CanIKickIt.OnCombatEvent then CanIKickIt.OnCombatEvent(subevent, srcGUID, srcName, dstGUID, dstName, spellId, spellName) end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, distribution, sender = ...
        if CanIKickIt.OnComm then CanIKickIt.OnComm(prefix, message, distribution, sender) end
    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        if CanIKickIt.OnNameplateEvent then CanIKickIt.OnNameplateEvent(event, unit) end
    end
end)

CanIKickIt.Events = Events
return Events
