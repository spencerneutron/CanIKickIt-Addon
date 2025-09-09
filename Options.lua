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

-- Slider: Icon size
local slider = CreateFrame("Slider", "CanIKickIt_IconSizeSlider", panel, "OptionsSliderTemplate")
slider:SetWidth(200)
slider:SetPoint("TOPLEFT", cbShowLabels, "BOTTOMLEFT", 8, -24)
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

-- Reset to defaults button
local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
btn:SetPoint("TOPLEFT", fontSlider, "BOTTOMLEFT", 0, -18)
btn:SetSize(120, 24)
btn:SetText("Reset to defaults")
btn:SetScript("OnClick", function()
    NS.DB.iconAnchor = "right"
    NS.DB.iconSpacing = 2
    NS.DB.iconSize = 18
    NS.DB.debug = false
    NS.DB.showLabels = true
    NS.DB.labelFontSize = 12
    -- refresh UI controls
    panel.refresh()
    if NS.Nameplates_RefreshAll then NS.Nameplates_RefreshAll() end
end)

-- Panel refresh (called when panel shown)
function panel.refresh()
    cbShowLabels:SetChecked( not not NS.DB.showLabels )
    slider:SetValue(NS.DB.iconSize or 18)
    fontSlider:SetValue(NS.DB.labelFontSize or 12)
end

-- Panel okay/default hooks (optional)
function panel.default()
    NS.DB.iconAnchor = "right"
    NS.DB.iconSpacing = 2
    NS.DB.iconSize = 18
    NS.DB.debug = false
    NS.DB.showLabels = true
    NS.DB.labelFontSize = 12
    panel.refresh()
end

InterfaceOptions_AddCategory(panel)

-- Ensure panel initializes from DB when loaded
panel:RegisterEvent("ADDON_LOADED")
panel:SetScript("OnEvent", function(self, event, name)
    if name == NS.ADDON_NAME then
        if not NS.DB then NS.DB = {} end
        -- ensure defaults are applied by Core.applyDefaults during ADDON_LOADED
        if not NS.DB.iconSize then NS.DB.iconSize = 18 end
        panel.refresh()
    end
end)
