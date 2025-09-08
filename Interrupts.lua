local addonName, CanIKickIt = ...
local Interrupts = {}

-- Register a simple inferred cooldown when an interrupt is observed
function CanIKickIt.OnCombatEvent(subevent, srcGUID, srcName, dstGUID, dstName, spellId, spellName)
    if subevent == "SPELL_INTERRUPT" then
        -- src is the interrupter, dst is the interrupted
        CanIKickIt.Cooldowns = CanIKickIt.Cooldowns or {}
        if CanIKickIt.Cooldowns.SetCooldown then
            CanIKickIt.Cooldowns:SetCooldown(srcGUID, 15) -- assume 15s player interrupt cooldown
        end
    end
end

CanIKickIt.Interrupts = Interrupts
return Interrupts
