local addonName, CanIKickIt = ...
local Nameplates = {}

-- Simple nameplate frame pooling helper
Nameplates.pool = Nameplates.pool or {}

function Nameplates:Acquire()
    local f = table.remove(self.pool)
    if f and f:IsShown() then f:Hide() end
    if not f then
        f = CreateFrame("Frame")
    end
    return f
end

function Nameplates:Release(f)
    if f then f:Hide() table.insert(self.pool, f) end
end

function Nameplates:GetNameplateForUnit(unit)
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        return C_NamePlate.GetNamePlateForUnit(unit)
    end
    return nil
end

CanIKickIt.Nameplates = Nameplates
return Nameplates
