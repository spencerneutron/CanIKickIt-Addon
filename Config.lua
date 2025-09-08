local addonName, CanIKickIt = ...
local Config = {}

CanIKickIt.db = _G.CanIKickItDB or {}
CanIKickIt.db.profile = CanIKickIt.db.profile or { enabled = true, announce = true }

function Config.GetProfile()
    return CanIKickIt.db.profile
end

CanIKickIt.Config = Config
return Config
