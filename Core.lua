local addonName, CanIKickIt = ...
CanIKickIt = CanIKickIt or {}

-- Basic initialization and module wiring
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        _G.CanIKickItDB = _G.CanIKickItDB or { profile = { } }

        -- try to embed AceComm if available
        if LibStub and LibStub:GetLibrary and LibStub:GetLibrary("AceComm-3.0", true) then
            local AceComm = LibStub:GetLibrary("AceComm-3.0")
            if AceComm and AceComm.Embed then
                AceComm:Embed(CanIKickIt)
            end
        end

        if CanIKickIt.Init then
            CanIKickIt.Init()
        end

        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Public API: register interrupt intent for macros
function CanIKickIt.RegisterInterruptIntent(spellName, targetName)
    CanIKickIt.interruptIntent = CanIKickIt.interruptIntent or {}
    CanIKickIt.interruptIntent[spellName] = targetName
    -- broadcast to party/raid as a compact message (prefix 'CIK')
    if CanIKickIt.SendCommMessage then
        local payload = spellName.."|"..(targetName or "")
        CanIKickIt:SendCommMessage("CanIKickIt", payload, IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY"))
    end
end

-- Expose a simple helper for macros
_G.CanIKickIt = CanIKickIt

return CanIKickIt
