local NS = select(2, ...)

local CD = {}  -- CD[player][spellID] = { start, duration, readyAt }

function NS.Cooldowns_Init() end

function NS.IsInterruptSpell(spellID)
  return NS.GetInterruptBySpellID(spellID) ~= nil
end

function NS.GetBaseCD(spellID, _srcGUID)
  return NS.GetBaseCD(spellID)  -- currently no per-source adjustment
end

function NS.Cooldowns_Start(player, spellID, duration)
  CD[player] = CD[player] or {}
  local now = NS.Now()
  CD[player][spellID] = { start = now, duration = duration, readyAt = now + duration }
  NS.Nameplates_OnCooldownUpdate(player, spellID, CD[player][spellID].readyAt)
end

function NS.Cooldowns_OnRemoteCD(spellID, player, startedAt, duration)
  CD[player] = CD[player] or {}
  CD[player][spellID] = { start = startedAt, duration = duration, readyAt = startedAt + duration }
  NS.Nameplates_OnCooldownUpdate(player, spellID, startedAt + duration)
end

function NS.Cooldowns_Get(player, spellID)
  local e = CD[player] and CD[player][spellID]
  if not e then return 0 end
  local remain = math.max(0, e.readyAt - NS.Now())
  return remain
end
