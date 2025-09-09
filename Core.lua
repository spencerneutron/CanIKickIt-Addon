-- Core.lua (top)
local ADDON, NS = ...
_G.CanIKickIt = NS

NS.ADDON_NAME = ADDON
NS.PREFIX     = "CIKI"
NS.VERSION    = "0.1.4"

-- Temporary DB so early files can call NS:Log without nil errors
NS.DB = NS.DB or { debug = false, iconAnchor = "right", iconSpacing = 2, iconSize = 18 }

-- Logger (guarded)
function NS:Log(...) if NS.DB and NS.DB.debug then print("|cff66cfffCIKI|r:", ...) end end

local E = CreateFrame("Frame")
NS._eventFrame = E

local function applyDefaults(db)
  -- only set when nil; never clobber user values
  if db.iconAnchor == nil  then db.iconAnchor  = "right" end
  if db.iconSpacing == nil then db.iconSpacing = 2 end
  if db.iconSize == nil    then db.iconSize    = 18 end
  if db.debug == nil       then db.debug       = false end
end

local function OnEvent(_, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name == NS.ADDON_NAME then
      -- Bind to the actual SavedVariables table and apply defaults/migrations here
      CanIKickItDB = CanIKickItDB or {}
      NS.DB = CanIKickItDB
      applyDefaults(NS.DB)

      -- (optional) versioned migrations
      NS.DB.version = NS.DB.version or NS.VERSION
      -- if NS.DB.version ~= NS.VERSION then ... migrate fields ...; NS.DB.version = NS.VERSION end

      -- Register world-ready events afterwards
      E:RegisterEvent("PLAYER_ENTERING_WORLD")
      E:RegisterEvent("PLAYER_LEAVING_WORLD")
      E:RegisterEvent("GROUP_ROSTER_UPDATE")
      E:RegisterEvent("ZONE_CHANGED_NEW_AREA")
      E:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
      E:RegisterEvent("PLAYER_TALENT_UPDATE")

      -- (optional) a cleanup before save to keep DB lean
      E:RegisterEvent("PLAYER_LOGOUT")

      NS.InitConfig() -- if you have UI bits; keep it pure (no world calls)
      NS:Log("ADDON_LOADED ok")
    end

  elseif event == "PLAYER_ENTERING_WORLD" then
    local isLogin, isReload = ...
    C_ChatInfo.RegisterAddonMessagePrefix(NS.PREFIX)
    NS.Comm_Init()
    NS.Events_Init()
    NS.Nameplates_Init()
    NS.Cooldowns_Init()
    C_Timer.After(0, function()
      NS.RecomputePlayerInterrupts()
      NS.RefreshAllVisiblePlates()
    end)
    NS:Log("PLAYER_ENTERING_WORLD (login="..tostring(isLogin)..", reload="..tostring(isReload)..")")

  elseif event == "PLAYER_LEAVING_WORLD" then
    NS.ClearTransientState()

  elseif event == "PLAYER_LOGOUT" then
    -- prune anything transient that may have leaked into NS.DB (defensive)
    if NS.DB then
      NS.DB._session = nil
      -- Do NOT store frames, functions, or massive caches in SV.
    end

  elseif event == "GROUP_ROSTER_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
    NS.RecomputePlayerInterrupts()
    NS.RefreshAllVisiblePlates()

  elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
    local unit = ...
    if not unit or unit == "player" then
      NS.RecomputePlayerInterrupts()
    end
  end
end

E:SetScript("OnEvent", OnEvent)
E:RegisterEvent("ADDON_LOADED")
