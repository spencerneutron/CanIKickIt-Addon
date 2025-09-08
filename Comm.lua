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
  local payload = NS.Encode({"assign", guid, spellID, player, ts})
  NS:Log("Comm_SendAssign: sending", guid, spellID, player, "dist="..tostring(dist))
  NS:SendCommMessage(NS.PREFIX, payload, dist)
  NS:Log("TX assign", guid, spellID, player)
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
  local payload = NS.Encode({"cd", spellID, player, startedAt, duration})
  NS:Log("Comm_SendCD: sending", spellID, player, "dist="..tostring(dist))
  NS:SendCommMessage(NS.PREFIX, payload, dist)
  NS:Log("TX cd", spellID, player)
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
    local spellID, player, startedAt, duration = tonumber(parts[2]), parts[3], tonumber(parts[4]), tonumber(parts[5])
    NS:Log("RX cd", spellID, player, sender)
    if player ~= me then
      NS.Cooldowns_OnRemoteCD(spellID, player, startedAt, duration)
    else
      NS:Log("Ignored cd from self", spellID, player, sender)
    end
  else
    NS:Log("Comm_OnMessage: unknown message type", t, "from", sender)
  end
end
