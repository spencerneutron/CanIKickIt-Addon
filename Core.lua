-- Core.lua
local ADDON, NS = ...
_G.CanIKickIt = NS  -- optional: expose for /dump etc.

NS.ADDON_NAME = ADDON
NS.PREFIX     = "CIKI"
NS.VERSION    = "0.1.0"

-- SavedVariables root (created by TOC: ## SavedVariables: CanIKickItDB)
CanIKickItDB = CanIKickItDB or {}
NS.DB = CanIKickItDB

-- simple logger (guarded)
function NS:Log(...)
  if NS.DB.debug then
    print("|cff66cfffCIKI|r:", ...)
  end
end

-- single hidden event frame + dispatcher
local E = CreateFrame("Frame")
NS._eventFrame = E

local function OnEvent(_, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name == NS.ADDON_NAME then
      E:UnregisterEvent("ADDON_LOADED")
      -- SV defaults & tiny config init are safe here
      NS.InitConfig()              -- Config.lua: sets defaults, no world calls
      -- Keep heavy work deferred
      -- Register world-ready events once:
      E:RegisterEvent("PLAYER_ENTERING_WORLD")
      E:RegisterEvent("PLAYER_LEAVING_WORLD")
      E:RegisterEvent("GROUP_ROSTER_UPDATE")
      E:RegisterEvent("ZONE_CHANGED_NEW_AREA")
      E:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
      E:RegisterEvent("PLAYER_TALENT_UPDATE")
      NS:Log("ADDON_LOADED ok")
    end

  elseif event == "PLAYER_ENTERING_WORLD" then
    -- Arguments: isLogin, isReload
    local isLogin, isReload = ...
    -- Now it’s safe to touch comms, plates, etc.
    C_ChatInfo.RegisterAddonMessagePrefix(NS.PREFIX)  -- required even with AceComm
    NS.Comm_Init()            -- Comm.lua (AceComm:Embed + RegisterComm)
    NS.Events_Init()          -- Events.lua (register CL & nameplate events)
    NS.Nameplates_Init()      -- Nameplates.lua (local caches/frames only)
    NS.Cooldowns_Init()       -- Cooldowns.lua (tables only)
    -- Optional: tiny defer to let frames settle before first refresh
    C_Timer.After(0, function()
      NS.RecomputePlayerInterrupts()  -- see function below
      NS.RefreshAllVisiblePlates()    -- see function below
    end)
    NS:Log("PLAYER_ENTERING_WORLD (login="..tostring(isLogin)..", reload="..tostring(isReload)..")")

  elseif event == "PLAYER_LEAVING_WORLD" then
    -- Drop transient state tied to current instance/zone (not SV)
    NS.ClearTransientState()          -- you implement: clear assignment caches if desired

  elseif event == "GROUP_ROSTER_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
    -- Group/instance context changed: light recompute
    NS.RecomputePlayerInterrupts()
    NS.RefreshAllVisiblePlates()

  elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
    -- Player spec/talents changed: update preferred interrupt + table lookups
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
  local unit = nil
  if UnitExists("focus") and UnitCanAttack("player", "focus") then
    unit = "focus"
  elseif UnitExists("target") and UnitCanAttack("player", "target") then
    unit = "target"
  end
  if not unit then
    NS:Log("AssignIntent: no hostile focus or target")
    return
  end

  local guid = UnitGUID(unit)
  if not guid then
    NS:Log("AssignIntent: no GUID for unit", unit)
    return
  end

  local player = UnitName("player")
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
