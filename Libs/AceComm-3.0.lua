--- AceComm-3.0 (vendor - trimmed but functional for basic send/receive and multipart handling)
local MAJOR, MINOR = "AceComm-3.0", 9

local AceComm, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not AceComm then return end

local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")
local CTL = assert(ChatThrottleLib, "AceComm-3.0 requires ChatThrottleLib")

local type, next, pairs, tostring = type, next, pairs, tostring
local strsub, match = string.sub, string.match
local tinsert, tconcat = table.insert, table.concat

local MSG_MULTI_FIRST = "\001"
local MSG_MULTI_NEXT  = "\002"
local MSG_MULTI_LAST  = "\003"
local MSG_ESCAPE = "\004"

AceComm.multipart_spool = AceComm.multipart_spool or {}
AceComm.embeds = AceComm.embeds or {}

function AceComm:RegisterComm(prefix, method)
    if method == nil then method = "OnCommReceived" end
    if #prefix > 16 then error("AceComm:RegisterComm(prefix,method): prefix length is limited to 16 characters") end
    RegisterAddonMessagePrefix(prefix)
    return AceComm._RegisterComm(self, prefix, method)
end

function AceComm:SendCommMessage(prefix, text, distribution, target, prio, callbackFn, callbackArg)
    prio = prio or "NORMAL"
    if not( type(prefix)=="string" and type(text)=="string" and type(distribution)=="string") then
        error('Usage: SendCommMessage(addon, "prefix", "text", "distribution"[, "target"[, "prio"[, callbackFn, callbackarg]]])', 2)
    end

    local textlen = #text
    local maxtextlen = 255
    local queueName = prefix..distribution..(target or "")

    local ctlCallback = nil
    if callbackFn then
        ctlCallback = function(sent) return callbackFn(callbackArg, sent, textlen) end
    end

    local forceMultipart
    if match(text, "^[\001-\009]") then
        if textlen+1 > maxtextlen then forceMultipart = true else text = "\004" .. text end
    end

    if not forceMultipart and textlen <= maxtextlen then
        CTL:SendAddonMessage(prio, prefix, text, distribution, target, queueName, ctlCallback, textlen)
    else
        maxtextlen = maxtextlen - 1
        local chunk = strsub(text, 1, maxtextlen)
        CTL:SendAddonMessage(prio, prefix, MSG_MULTI_FIRST..chunk, distribution, target, queueName, ctlCallback, maxtextlen)
        local pos = 1+maxtextlen
        while pos+maxtextlen <= textlen do
            chunk = strsub(text, pos, pos+maxtextlen-1)
            CTL:SendAddonMessage(prio, prefix, MSG_MULTI_NEXT..chunk, distribution, target, queueName, ctlCallback, pos+maxtextlen-1)
            pos = pos + maxtextlen
        end
        chunk = strsub(text, pos)
        CTL:SendAddonMessage(prio, prefix, MSG_MULTI_LAST..chunk, distribution, target, queueName, ctlCallback, textlen)
    end
end

-- Receiving
local function new_compost()
    local compost = setmetatable({}, {__mode = "k"})
    return function()
        local t = next(compost)
        if t then compost[t]=nil for i=#t,3,-1 do t[i]=nil end return t end
        return {}
    end
end
local pull = new_compost()

local function lostdatawarning(prefix,sender,where)
    DEFAULT_CHAT_FRAME:AddMessage(MAJOR..": Warning: lost network data regarding '"..tostring(prefix).."' from '"..tostring(sender).."' (in "..where..")")
end

function AceComm:OnReceiveMultipartFirst(prefix, message, distribution, sender)
    local key = prefix.."\t"..distribution.."\t"..sender
    AceComm.multipart_spool[key] = message
end

function AceComm:OnReceiveMultipartNext(prefix, message, distribution, sender)
    local key = prefix.."\t"..distribution.."\t"..sender
    local olddata = AceComm.multipart_spool[key]
    if not olddata then return end
    if type(olddata)~="table" then
        local t = pull()
        t[1] = olddata
        t[2] = message
        AceComm.multipart_spool[key] = t
    else
        tinsert(olddata, message)
    end
end

function AceComm:OnReceiveMultipartLast(prefix, message, distribution, sender)
    local key = prefix.."\t"..distribution.."\t"..sender
    local olddata = AceComm.multipart_spool[key]
    if not olddata then return end
    AceComm.multipart_spool[key] = nil
    if type(olddata) == "table" then
        tinsert(olddata, message)
        AceComm.callbacks:Fire(prefix, tconcat(olddata, ""), distribution, sender)
    else
        AceComm.callbacks:Fire(prefix, olddata..message, distribution, sender)
    end
end

if not AceComm.callbacks then
    AceComm.callbacks = CallbackHandler:New(AceComm, "_RegisterComm", "UnregisterComm", "UnregisterAllComm")
end

local function OnEvent(self, event, prefix, message, distribution, sender)
    if event == "CHAT_MSG_ADDON" then
        sender = Ambiguate(sender, "none")
        local control, rest = match(message, "^([\001-\009])(.*)")
        if control then
            if control==MSG_MULTI_FIRST then AceComm:OnReceiveMultipartFirst(prefix, rest, distribution, sender)
            elseif control==MSG_MULTI_NEXT then AceComm:OnReceiveMultipartNext(prefix, rest, distribution, sender)
            elseif control==MSG_MULTI_LAST then AceComm:OnReceiveMultipartLast(prefix, rest, distribution, sender)
            elseif control==MSG_ESCAPE then AceComm.callbacks:Fire(prefix, rest, distribution, sender)
            end
        else
            AceComm.callbacks:Fire(prefix, message, distribution, sender)
        end
    else
        assert(false, "Received "..tostring(event).." event?!")
    end
end

AceComm.frame = AceComm.frame or CreateFrame("Frame", "AceComm30Frame")
AceComm.frame:SetScript("OnEvent", OnEvent)
AceComm.frame:UnregisterAllEvents()
AceComm.frame:RegisterEvent("CHAT_MSG_ADDON")

local mixins = {"RegisterComm","UnregisterComm","UnregisterAllComm","SendCommMessage"}
function AceComm:Embed(target)
    for k, v in pairs(mixins) do target[v] = self[v] end
    self.embeds[target] = true
    return target
end

function AceComm:OnEmbedDisable(target)
    target:UnregisterAllComm()
end

for target, v in pairs(AceComm.embeds) do AceComm:Embed(target) end

return AceComm
