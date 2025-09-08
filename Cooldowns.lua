local addonName, CanIKickIt = ...
local Cooldowns = {}

-- track interrupt cooldowns per player by GUID
Cooldowns.interrupts = Cooldowns.interrupts or {}

function Cooldowns:SetCooldown(guid, duration)
    self.interrupts[guid] = time() + (duration or 0)
end

function Cooldowns:IsOnCooldown(guid)
    local t = self.interrupts[guid]
    if not t then return false end
    return time() < t
end

CanIKickIt.Cooldowns = Cooldowns
return Cooldowns
