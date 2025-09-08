-- Minimal LibStub implementation (sufficient for vendored libs)
local LibStub = LibStub or {}
LibStub._libs = LibStub._libs or {}

function LibStub:NewLibrary(name, minor)
    local old = self._libs[name]
    if old and old.minor and old.minor >= minor then return nil end
    local lib = old or {}
    lib.minor = minor
    self._libs[name] = lib
    return lib
end

function LibStub:GetLibrary(name, silent)
    local lib = self._libs[name]
    if not lib and not silent then error("Library '"..tostring(name).."' not found", 2) end
    return lib
end

return LibStub
