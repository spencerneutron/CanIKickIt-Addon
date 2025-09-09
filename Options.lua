local ADDON, NS = ...

-- Minimal Blizzard Interface Options panel for CanIKickIt
local panel = CreateFrame("Frame", "CanIKickItOptionsPanel", UIParent)
panel.name = "Can I Kick It"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Can I Kick It")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
subtitle:SetText("Minimal options for icon layout and labels.")

-- Checkbox: Show short player labels
local cbShowLabels = CreateFrame("CheckButton", "CanIKickIt_ShowLabelsCB", panel, "InterfaceOptionsCheckButtonTemplate")
cbShowLabels:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -12)
cbShowLabels.Text:SetText("Show short player labels")
cbShowLabels.tooltip = "Show the first four letters of the assigned player above the icon."
cbShowLabels:SetScript("OnClick", function(self)
    NS.DB.showLabels = self:GetChecked() and true or false
    if NS.Nameplates_RefreshAll then NS.Nameplates_RefreshAll() end
end)

-- Checkbox: Enable debug logging
local cbDebug = CreateFrame("CheckButton", "CanIKickIt_DebugCB", panel, "InterfaceOptionsCheckButtonTemplate")
cbDebug:SetPoint("TOPLEFT", cbShowLabels, "BOTTOMLEFT", 0, -12)
cbDebug.Text:SetText("Enable debug logging")
cbDebug.tooltip = "Print debug messages to the default chat when enabled."
cbDebug:SetScript("OnClick", function(self)
    NS.DB.debug = self:GetChecked() and true or false
end)

-- Slider: Icon size
local slider = CreateFrame("Slider", "CanIKickIt_IconSizeSlider", panel, "OptionsSliderTemplate")
slider:SetWidth(200)
-- place sliders in a right-hand column so checkboxes form a tidy left column
local rightColX = 260
slider:SetPoint("TOPLEFT", title, "TOPLEFT", rightColX, -40)
slider:SetMinMaxValues(8, 48)
slider:SetValueStep(1)
slider.Text = _G[slider:GetName() .. "Text"]
slider.Low = _G[slider:GetName() .. "Low"]
slider.High = _G[slider:GetName() .. "High"]
slider.Text:SetText("Icon size")
slider.Low:SetText("8")
slider.High:SetText("48")
slider:SetScript("OnValueChanged", function(self, v)
    NS.DB.iconSize = math.floor(v + 0.5)
    if NS.Nameplates_RefreshAll then NS.Nameplates_RefreshAll() end
end)

-- Slider: Label font size
local fontSlider = CreateFrame("Slider", "CanIKickIt_LabelFontSlider", panel, "OptionsSliderTemplate")
fontSlider:SetWidth(200)
fontSlider:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -28)
fontSlider:SetMinMaxValues(8, 24)
fontSlider:SetValueStep(1)
fontSlider.Text = _G[fontSlider:GetName() .. "Text"]
fontSlider.Low = _G[fontSlider:GetName() .. "Low"]
fontSlider.High = _G[fontSlider:GetName() .. "High"]
fontSlider.Text:SetText("Label font size")
fontSlider.Low:SetText("8")
fontSlider.High:SetText("24")
fontSlider:SetScript("OnValueChanged", function(self, v)
    NS.DB.labelFontSize = math.floor(v + 0.5)
    if NS.Nameplates_RefreshAll then NS.Nameplates_RefreshAll() end
end)

-- Checkbox: Enable cooldown sync (broadcast local CD changes)
local cbSync = CreateFrame("CheckButton", "CanIKickIt_SyncCB", panel, "InterfaceOptionsCheckButtonTemplate")
-- push the right-column checkbox stack further down so it doesn't collide with the sliders
cbSync:SetPoint("TOPLEFT", fontSlider, "BOTTOMLEFT", -2, -60)
cbSync.Text:SetText("Enable cooldown sync")
cbSync.tooltip = "Broadcast cooldown changes to other addon users when enabled."
cbSync:SetScript("OnClick", function(self)
    NS.DB.syncMode = self:GetChecked() and true or false
end)

-- Checkbox: Observer mode
local cbObserver = CreateFrame("CheckButton", "CanIKickIt_ObserverCB", panel, "InterfaceOptionsCheckButtonTemplate")
cbObserver:SetPoint("TOPLEFT", cbSync, "BOTTOMLEFT", 0, -12)
cbObserver.Text:SetText("Observer mode (party only)")
cbObserver.tooltip = "Infer interrupts from non-addon party members and show as low-priority observed assignments."
cbObserver:SetScript("OnClick", function(self)
    NS.DB.observerMode = self:GetChecked() and true or false
    if NS.Nameplates_RefreshAll then NS.Nameplates_RefreshAll() end
end)

-- Checkbox: Anchor icons to left (otherwise right)
local cbAnchorLeft = CreateFrame("CheckButton", "CanIKickIt_AnchorLeftCB", panel, "InterfaceOptionsCheckButtonTemplate")
cbAnchorLeft:SetPoint("TOPLEFT", cbObserver, "BOTTOMLEFT", 0, -12)
cbAnchorLeft.Text:SetText("Anchor icons to left")
cbAnchorLeft.tooltip = "When checked, icons grow to the right from the nameplate; otherwise they grow to the left."
cbAnchorLeft:SetScript("OnClick", function(self)
    NS.DB.iconAnchor = self:GetChecked() and "left" or "right"
    if NS.Nameplates_RefreshAll then NS.Nameplates_RefreshAll() end
end)

-- Slider: Icon spacing
local spacingSlider = CreateFrame("Slider", "CanIKickIt_IconSpacingSlider", panel, "OptionsSliderTemplate")
spacingSlider:SetWidth(200)
spacingSlider:SetPoint("TOPLEFT", fontSlider, "BOTTOMLEFT", 0, -28)
spacingSlider:SetMinMaxValues(0, 16)
spacingSlider:SetValueStep(1)
spacingSlider.Text = _G[spacingSlider:GetName() .. "Text"]
spacingSlider.Low = _G[spacingSlider:GetName() .. "Low"]
spacingSlider.High = _G[spacingSlider:GetName() .. "High"]
spacingSlider.Text:SetText("Icon spacing")
spacingSlider.Low:SetText("0")
spacingSlider.High:SetText("16")
spacingSlider:SetScript("OnValueChanged", function(self, v)
    NS.DB.iconSpacing = math.floor(v + 0.5)
    if NS.Nameplates_RefreshAll then NS.Nameplates_RefreshAll() end
end)

-- Reset to defaults button
local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
-- move Reset button to left column under the checkbox stack and nudge down for spacing
btn:SetPoint("TOPLEFT", cbAnchorLeft, "BOTTOMLEFT", 0, -36)
btn:SetSize(120, 24)
btn:SetText("Reset to defaults")
btn:SetScript("OnClick", function()
    NS.DB.iconAnchor = "right"
    NS.DB.iconSpacing = 2
    NS.DB.iconSize = 18
    NS.DB.debug = false
    NS.DB.showLabels = true
    NS.DB.labelFontSize = 12
    NS.DB.observerMode = true
    NS.DB.syncMode = true
    -- refresh UI controls
    panel.refresh()
    if NS.Nameplates_RefreshAll then NS.Nameplates_RefreshAll() end
end)

-- Panel refresh (called when panel shown)
function panel.refresh()
    cbShowLabels:SetChecked( not not NS.DB.showLabels )
    slider:SetValue(NS.DB.iconSize or 18)
    fontSlider:SetValue(NS.DB.labelFontSize or 12)
    cbDebug:SetChecked(not not NS.DB.debug)
    cbSync:SetChecked(not not NS.DB.syncMode)
    cbObserver:SetChecked(not not NS.DB.observerMode)
    cbAnchorLeft:SetChecked(NS.DB.iconAnchor == "left")
    spacingSlider:SetValue(NS.DB.iconSpacing or 2)
end

-- Panel okay/default hooks (optional)
function panel.default()
    NS.DB.iconAnchor = "right"
    NS.DB.iconSpacing = 2
    NS.DB.iconSize = 18
    NS.DB.debug = false
    NS.DB.showLabels = true
    NS.DB.labelFontSize = 12
    NS.DB.observerMode = true
    NS.DB.syncMode = true
    panel.refresh()
end

-- Attach panel and initialize when the addon loads (retail-safe)
-- Initialization entrypoint called from Core during ADDON_LOADED
function NS.InitOptions()
    -- ensure saved-vars exist and minimal defaults for the panel
    if not NS.DB then NS.DB = {} end
    if not NS.DB.iconSize then NS.DB.iconSize = 18 end

    -- Add to Interface Options: try legacy API, otherwise attempt to load Blizzard module and fall back to parenting
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    else
        if LoadAddOn then pcall(LoadAddOn, "Blizzard_InterfaceOptions") end
        if InterfaceOptions_AddCategory then
            InterfaceOptions_AddCategory(panel)
        elseif Settings and Settings.RegisterCanvasLayoutCategory then
            local category, layout = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
            Settings.RegisterAddOnCategory(category)
            NS.settingsCategory = category
        elseif InterfaceOptionsFramePanelContainer then
            panel:SetParent(InterfaceOptionsFramePanelContainer)
        end
    end

    panel.refresh()
end

-- Slash command to open the options panel; prefer legacy API then Settings API
SlashCmdList.CanIKickIt = function(msg)
    -- try legacy OpenToCategory (Blizzard bug requires calling twice)
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(ADDON)
        InterfaceOptionsFrame_OpenToCategory(ADDON)
        return
    end

    -- try Settings API if we registered a category
    if NS.settingsCategory and Settings.OpenToCategory then
        Settings.OpenToCategory(NS.settingsCategory.ID)
        return
    end

    -- last resort: show the Interface Options frame
    if InterfaceOptionsFrame then
        InterfaceOptionsFrame:Show()
    end
end
SLASH_CanIKickIt1 = "/ciki"
SLASH_CanIKickIt2 = "/canikickit"
