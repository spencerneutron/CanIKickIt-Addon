local addonName, CanIKickIt = ...
local Comm = {}

-- Use AceComm's RegisterComm if available
if CanIKickIt.RegisterComm then
    CanIKickIt:RegisterComm("CanIKickIt", "OnCommReceived")
end

function CanIKickIt.OnCommReceived(prefix, message, distribution, sender)
    -- simple pipe-delimited payload: spell|target
    local spell, target = string.match(message, "^([^|]+)|?(.*)")
    if spell then
        CanIKickIt.remoteInterrupts = CanIKickIt.remoteInterrupts or {}
        CanIKickIt.remoteInterrupts[sender] = { spell = spell, target = target }
        if CanIKickIt.Config and CanIKickIt.Config.GetProfile().announce then
            print("[CanIKickIt] "..sender.." wants to interrupt "..spell..(target~= "" and (" on "..target) or ""))
        end
    end
end

CanIKickIt.Comm = Comm
return Comm
