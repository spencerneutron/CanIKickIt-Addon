local addonName, CanIKickIt = ...
local Targeting = {}

function Targeting:GetUnitGUID(unit)
    if UnitExists(unit) then return UnitGUID(unit) end
    return nil
end

function Targeting:GetHostileTargets()
    local t = {}
    for i=1,40 do
        local unit = "nameplate"..i
        if UnitExists(unit) and UnitCanAttack("player", unit) then
            t[unit] = UnitGUID(unit)
        end
    end
    return t
end

CanIKickIt.Targeting = Targeting
return Targeting
