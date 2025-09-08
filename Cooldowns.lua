local NS = select(2, ...)

local CD = {}  -- CD[player][spellID] = { start, duration, readyAt }

function NS.Cooldowns_Init() end

function NS.IsInterruptSpell(spellID)
  spellID = NS.ResolveSpellID(spellID) or spellID
  return NS.GetInterruptBySpellID(spellID) ~= nil
end

-- Use the Interrupts.lua API directly; do NOT shadow it here.
-- If you want a wrapper, alias it without reusing the same name:
local GetBaseCDFromTable = NS.GetBaseCD  -- defined in Interrupts.lua

function NS.Cooldowns_Start(player, spellID, duration)
  spellID = NS.ResolveSpellID(spellID) or spellID
  CD[player] = CD[player] or {}
  local now = NS.Now()
  CD[player][spellID] = { start = now, duration = duration, readyAt = now + duration }
  NS.Nameplates_NotifyCooldownChanged(player, spellID)
end

function NS.Cooldowns_OnRemoteCD(spellID, player, startedAt, duration)
  spellID = NS.ResolveSpellID(spellID) or spellID
  CD[player] = CD[player] or {}
  CD[player][spellID] = { start = startedAt, duration = duration, readyAt = startedAt + duration }
  NS.Nameplates_NotifyCooldownChanged(player, spellID)
end

-- Return start,duration,(readyAt|nil) for UI to set the Cooldown once.
function NS.Cooldowns_GetInfo(player, spellID)
  spellID = NS.ResolveSpellID(spellID) or spellID
  local e = CD[player] and CD[player][spellID]
  if not e then return nil end
  return e.start, e.duration, e.readyAt
end

-- (Optional) expose if Events.lua wants base CD:
function NS.Cooldowns_GetBaseCD(spellID)
  spellID = NS.ResolveSpellID(spellID) or spellID
  return GetBaseCDFromTable(spellID)
end
