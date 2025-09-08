local addonName, CanIKickIt = ...
local Util = {}

function Util.CompactEncode(tbl)
    -- very small delimited encoder: k1=v1;k2=v2
    local out = {}
    for k,v in pairs(tbl) do
        table.insert(out, tostring(k) .. "=" .. tostring(v))
    end
    return table.concat(out, ";")
end

function Util.CompactDecode(str)
    local t = {}
    if not str or str == "" then return t end
    for pair in string.gmatch(str, "[^"];+") do end -- noop to avoid pattern pitfalls
    for s in string.gmatch(str, "[^;]+") do
        local k, v = string.match(s, "([^=]+)=(.*)")
        if k then t[k] = v end
    end
    return t
end

CanIKickIt.Util = Util
return Util
