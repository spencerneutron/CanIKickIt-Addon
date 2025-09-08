local NS = select(2, ...)
local AceComm = LibStub("AceComm-3.0")

local DIST = { party="PARTY" , raid="RAID", inst="INSTANCE_CHAT" }

function NS.Comm_Init()
  -- AceComm receiver setup only; Core handles prefix registration
  AceComm:Embed(NS)
  NS:RegisterComm(NS.PREFIX, "Comm_OnMessage")
end

-- choose distribution based on current group
local function GetDist()
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return DIST.inst end
  if IsInRaid() then return DIST.raid end
  if IsInGroup() then return DIST.party end
  return nil
end

function NS.Comm_SendAssign(guid, spellID, player, ts)
  local dist = GetDist()
  if not dist then return end
  local payload = NS.Encode({"assign", guid, spellID, player, ts})
  NS:SendCommMessage(NS.PREFIX, payload, dist)
  NS:Log("TX assign", guid, spellID, player)
end

function NS.Comm_SendCD(spellID, player, startedAt, duration)
  if not NS.DB.syncMode then return end
  local dist = GetDist()
  if not dist then return end
  local payload = NS.Encode({"cd", spellID, player, startedAt, duration})
  NS:SendCommMessage(NS.PREFIX, payload, dist)
  NS:Log("TX cd", spellID, player)
end

function NS:Comm_OnMessage(prefix, msg, dist, sender)
  if prefix ~= NS.PREFIX then return end
  local parts = NS.Decode(msg)
  local t = parts[1]
  if t == "assign" then
    local guid, spellID, player, ts = parts[2], tonumber(parts[3]), parts[4], tonumber(parts[5])
    NS.Assignments_OnRemoteAssign(guid, spellID, player, ts)
  elseif t == "cd" then
    local spellID, player, startedAt, duration = tonumber(parts[2]), parts[3], tonumber(parts[4]), tonumber(parts[5])
    NS.Cooldowns_OnRemoteCD(spellID, player, startedAt, duration)
  end
end
