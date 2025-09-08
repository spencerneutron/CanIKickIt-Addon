local NS = select(2, ...)

local CD = {}  -- CD[player][spellID] = { start, duration, readyAt }

function NS.Cooldowns_Init() end

function NS.IsInterruptSpell(spellID)
  return NS.GetInterruptBySpellID(spellID) ~= nil
end

function NS.GetBaseCD(spellID, _srcGUID)
  return NS.GetBaseCD(spellID)
end

function NS.Cooldowns_Start(player, spellID, duration)
  CD[player] = CD[player] or {}
  local now = NS.Now()
  CD[player][spellID] = { start = now, duration = duration, readyAt = now + duration }
  NS.Nameplates_NotifyCooldownChanged(player, spellID)
end

function NS.Cooldowns_OnRemoteCD(spellID, player, startedAt, duration)
  CD[player] = CD[player] or {}
  CD[player][spellID] = { start = startedAt, duration = duration, readyAt = startedAt + duration }
  NS.Nameplates_NotifyCooldownChanged(player, spellID)
end

-- New: return start,duration (or nil) – let the UI set the cooldown once.
function NS.Cooldowns_GetInfo(player, spellID)
  local e = CD[player] and CD[player][spellID]
  if not e then return nil end
  return e.start, e.duration, e.readyAt
end
