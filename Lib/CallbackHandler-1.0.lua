-- Minimal CallbackHandler-1.0 compatible with AceComm usage
local CallbackHandler = LibStub:NewLibrary("CallbackHandler-1.0", 1)
if not CallbackHandler then return end

function CallbackHandler:New(owner, registerName, unregisterName, unregisterAllName)
    local cb = { owner = owner, handlers = {} }

    function cb:Fire(prefix, ...)
        local list = self.handlers[prefix]
        if list then
            for _, h in ipairs(list) do
                if type(h) == "function" then
                    h(...)
                elseif type(h) == "string" and owner and owner[h] then
                    owner[h](owner, ...)
                end
            end
        end
    end

    -- Create register/unregister helpers on owner (AceComm expects these names)
    owner[registerName] = function(_, prefix, method)
        cb.handlers[prefix] = cb.handlers[prefix] or {}
        if type(method) == "string" or type(method) == "function" then
            table.insert(cb.handlers[prefix], method)
        end
        return true
    end

    owner[unregisterName] = function(_, prefix)
        cb.handlers[prefix] = nil
    end

    owner[unregisterAllName] = function(_)
        cb.handlers = {}
    end

    return cb
end

return CallbackHandler
