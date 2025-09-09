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

-- ------- helpers that DO NOT touch the world at file load time -------------

function NS.RecomputePlayerInterrupts()
  -- forces a new preferred interrupt + caches (cheap)
  if NS.GetPreferredInterruptForPlayer then
    NS._preferredInterrupt = NS.GetPreferredInterruptForPlayer()
    NS:Log("Preferred interrupt:", NS._preferredInterrupt and NS._preferredInterrupt.name or "none")
  end
end

function NS.RefreshAllVisiblePlates()
  -- Safe call into your nameplate module to redraw current plates
  if NS.Nameplates_RefreshAll then
    NS.Nameplates_RefreshAll()
  end
end

function NS.ClearTransientState()
  -- e.g., wipe assignment lists if they should not persist across zones
  if NS.Assignments_Clear then
    NS.Assignments_Clear()
  end
end

function NS.AssignIntentCore(spellID)
  -- prefer explicit spellID, then preferred interrupt, then bail
  local sid = spellID or (NS._preferredInterrupt and NS._preferredInterrupt.spellID)
  sid = NS.ResolveSpellID(sid) or sid
  sid = tonumber(sid)
  if not sid then
    NS:Log("AssignIntent: no valid spellID provided")
    return
  end

  -- prefer hostile focus, then hostile target
  local unit = NS.FirstHostileUnit()
  if not unit then
    NS:Log("AssignIntent: no hostile focus or target")
    return
  end

  local guid = UnitGUID(unit)
  if not guid then
    NS:Log("AssignIntent: no GUID for unit", unit)
    return
  end
  
  local player = UnitName("player") or "player"
  local ts = NS.Now()

  -- apply locally as macro (macro-locked) and broadcast
  if NS.Assignments_Add then
    NS.Assignments_Add(guid, sid, player, ts, "macro")
  end
  if NS.Comm_SendAssign then
    NS.Comm_SendAssign(guid, sid, player, ts, "macro")
  end
  NS:Log("AssignIntent: assigned", guid, sid, player, "unit="..tostring(unit))
end
