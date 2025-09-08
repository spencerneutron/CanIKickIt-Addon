local ADDON, NS = ...
_G.CanIKickIt = NS

NS.ADDON_NAME = ADDON
NS.PREFIX = "CIKI"            -- addon comm prefix
NS.VERSION = "0.1.0"

-- SavedVariables defaults
CanIKickItDB = CanIKickItDB or {}
NS.DB = CanIKickItDB

-- simple logger
function NS:Log(...)
  if NS.DB.debug then
    print("|cff66cfffCIKI|r:", ...)
  end
end

-- lifecycle
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  NS.InitConfig()            -- Config.lua
  NS.Comm_Init()             -- Comm.lua
  NS.Events_Init()           -- Events.lua
  NS.Nameplates_Init()       -- Nameplates.lua
  NS.Cooldowns_Init()        -- Cooldowns.lua
  NS:Log("Loaded v" .. NS.VERSION)
end)
