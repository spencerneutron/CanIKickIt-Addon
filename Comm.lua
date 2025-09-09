local NS = select(2, ...)
local AceComm = (LibStub and LibStub.GetLibrary) and LibStub:GetLibrary("AceComm-3.0", true)

local DIST = { party="PARTY" , raid="RAID", inst="INSTANCE_CHAT" }

function NS.Comm_Init()
  -- AceComm receiver setup only; Core handles prefix registration
  if AceComm then
    AceComm:Embed(NS)
    NS:RegisterComm(NS.PREFIX, "Comm_OnMessage")
    NS:Log("Comm_Init: AceComm embedded and prefix registered")
  else
    NS:Log("AceComm not available; comm disabled")
  end
end

-- choose distribution based on current group
local function GetDist()
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then NS:Log("GetDist: INSTANCE_CHAT") return DIST.inst end
  if IsInRaid() then NS:Log("GetDist: RAID") return DIST.raid end
  if IsInGroup() then NS:Log("GetDist: PARTY") return DIST.party end
  NS:Log("GetDist: not in group, no distribution")
  return nil
end

function NS.Comm_SendAssign(guid, spellID, player, ts)
  local dist = GetDist()
  if not dist then
    NS:Log("Comm_SendAssign: no distribution available; not sending", guid, spellID, player)
    return
  end
  local canon = NS.ResolveSpellID(spellID) or spellID
  local payload = NS.Encode({"assign", guid, canon, player, ts})
  NS:Log("Comm_SendAssign: sending", guid, canon, player, "dist="..tostring(dist))
  NS:SendCommMessage(NS.PREFIX, payload, dist)
  NS:Log("TX assign", guid, canon, player)
end

function NS.Comm_SendCD(spellID, player, startedAt, duration)
  if not NS.DB.syncMode then
    NS:Log("Comm_SendCD: syncMode disabled; not sending", spellID, player)
    return
  end
  local dist = GetDist()
  if not dist then
    NS:Log("Comm_SendCD: no distribution available; not sending", spellID, player)
    return
  end

  local canon = NS.ResolveSpellID(spellID) or spellID

  -- compute remaining seconds on sender (use GetTime() local timescale)
  local rem = nil
  if type(startedAt) == "number" and type(duration) == "number" then
    rem = (startedAt + duration) - (GetTime() or 0)
  end
  if not rem or rem < 0 then
    rem = 0
  end

  -- Convert remaining into a server-global ready timestamp so receivers can compute remaining
  local serverReady = (GetServerTime and GetServerTime()) and (GetServerTime() + rem) or nil

  local payload = NS.Encode({"cd", canon, player, serverReady, rem})
  NS:Log("Comm_SendCD: sending", canon, player, "rem=", rem, "serverReady=", tostring(serverReady), "dist="..tostring(dist))
  NS:SendCommMessage(NS.PREFIX, payload, dist)
  NS:Log("TX cd", canon, player)
end

function NS:Comm_OnMessage(prefix, msg, dist, sender)
  if prefix ~= NS.PREFIX then
    NS:Log("Comm_OnMessage: unknown prefix received, ignoring", prefix, sender)
    return
  end
  local me = UnitName("player")
  NS:Log("Comm_OnMessage: received msg", msg, "from", sender, "via", dist)
  local parts = NS.Decode(msg)
  local t = parts[1]

  if t == "assign" then
    local guid, spellID, player, ts = parts[2], tonumber(parts[3]), parts[4], tonumber(parts[5])
    -- only handle assigns from other players (ignore our own echoes)
    if player ~= me then
      NS:Log("RX assign", guid, spellID, player, sender)
      NS.Assignments_OnRemoteAssign(guid, spellID, player, ts)
    else
      NS:Log("Ignored assign from self", guid, spellID, player, sender)
    end

  elseif t == "cd" then
    -- message format: { "cd", spellID, player, serverReady, remSent }
    local spellID, player = tonumber(parts[2]), parts[3]
    local serverReady = tonumber(parts[4])
    local remSent = tonumber(parts[5])

    NS:Log("RX cd", spellID, player, "serverReady=", tostring(serverReady), "remSent=", tostring(remSent), "from", sender)

    if player == me then
      NS:Log("Ignored cd from self", spellID, player, sender)
      return
    end

    -- Reconstruct remaining using server time (global)
    local remaining = nil
    if serverReady and GetServerTime then
      remaining = serverReady - GetServerTime()
    elseif remSent then
      -- fallback: use remaining sent directly (less robust)
      remaining = remSent
    end

    if not remaining or remaining <= 0 then
      NS:Log("RX cd: already ready or no remaining time; ignoring", spellID, player)
      return
    end

    -- Build a local start/duration so local UI can show a ticking cooldown
    local localStart = GetTime()
    local localDur = remaining

    NS.Cooldowns_OnRemoteCD(spellID, player, localStart, localDur)
  else
    NS:Log("Comm_OnMessage: unknown message type", t, "from", sender)
  end
end
