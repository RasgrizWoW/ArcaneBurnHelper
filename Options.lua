local addonName, ns = ...
ns = ns or _G.ArcaneBurnHelperNS

local optionsPanel, settingsCategory

function ns.OpenOptions()
    if optionsPanel and optionsPanel.refresh then
        optionsPanel.refresh()
    end
    if ns.IsModernSettings() and settingsCategory then
        Settings.OpenToCategory(settingsCategory.ID)
    elseif InterfaceOptionsFrame_OpenToCategory and optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    end
end

local function CreateSection(parent, titleText, x, y, width, height)
    local section = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
    section:SetSize(width, height)
    section:SetPoint("TOPLEFT", x, y)
    if section.SetBackdrop then
        section:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        section:SetBackdropColor(0.07, 0.07, 0.07, 0.88)
        section:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.7)
    end

    local title = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText(titleText)

    return section, title
end

local function CreateSlider(parent, name, minVal, maxVal, step, x, y, getter, setter, width, opts)
    opts = opts or {}
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:SetWidth(width or 220)
    _G[name .. "Low"]:SetText(tostring(minVal))
    _G[name .. "High"]:SetText(tostring(maxVal))
    slider.labelPrefix = ""
    slider.formatter = opts.formatter
    slider.round = opts.round ~= false

    local function normalize(value)
        if slider.round then
            return math.floor((value / step) + 0.5) * step
        end
        return value
    end

    local function formatValue(value)
        if slider.formatter then
            return slider.formatter(value)
        end
        if math.floor(value) == value then
            return tostring(value)
        end
        return string.format("%.2f", value)
    end

    slider:SetScript("OnValueChanged", function(self, value)
        value = normalize(value)
        setter(value)
        _G[name .. "Text"]:SetText(self.labelPrefix .. ": " .. formatValue(value))
        if ns.RefreshDisplay then
            ns.RefreshDisplay()
        end
    end)

    function slider:Refresh()
        local value = normalize(getter())
        self:SetValue(value)
        _G[name .. "Text"]:SetText(self.labelPrefix .. ": " .. formatValue(value))
    end

    return slider
end

local function StyleSliderBelow(slider, textured)
    local text = _G[slider:GetName() .. "Text"]
    local low = _G[slider:GetName() .. "Low"]
    local high = _G[slider:GetName() .. "High"]

    if textured then
        local bg = CreateFrame("Frame", nil, slider, BackdropTemplateMixin and "BackdropTemplate")
        bg:SetPoint("TOPLEFT", slider, -8, 10)
        bg:SetPoint("BOTTOMRIGHT", slider, 8, -14)
        if bg.SetBackdrop then
            bg:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            bg:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
            bg:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.7)
        end
        bg:SetFrameLevel(math.max(slider:GetFrameLevel() - 1, 0))
    end

    text:ClearAllPoints()
    text:SetPoint("TOP", slider, "BOTTOM", 0, -6)
    low:ClearAllPoints()
    low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -20)
    high:ClearAllPoints()
    high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -20)
end

function ns.CreateOptionsPanel()
    if optionsPanel then return end

    optionsPanel = CreateFrame("Frame", "ArcaneBurnHelperOptionsPanel", UIParent)
    optionsPanel.name = "Arcane Burn Helper"

    local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Arcane Burn Helper")

    local subtitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("TBC Anniversary settings")

    local optionScale = 0.80
    local leftX, rightX = 16, 326
    local topY = -50
    local sectionW = math.floor(350 * optionScale + 0.5)
    local sliderW = math.floor(250 * optionScale + 0.5)

    local rotationSection = CreateSection(optionsPanel, "Sustain Rotation", leftX, topY, sectionW, 144)
    local abSlider = CreateSlider(rotationSection, "ArcaneBurnHelperABSlider", 0, 6, 1, 16, -36,
        function() return ns.GetConfig().sustainAB end,
        function(v) ns.GetConfig().sustainAB = v end,
        sliderW)
    abSlider.labelPrefix = "Arcane Blast"
    StyleSliderBelow(abSlider, true)

    local fbSlider = CreateSlider(rotationSection, "ArcaneBurnHelperFBSlider", 0, 6, 1, 16, -88,
        function() return ns.GetConfig().sustainFB end,
        function(v) ns.GetConfig().sustainFB = v end,
        sliderW)
    fbSlider.labelPrefix = "Frostbolt"
    StyleSliderBelow(fbSlider, true)

    local armorSection = CreateSection(optionsPanel, "Armor", rightX, topY, sectionW, 96)
    local mageCheck = CreateFrame("CheckButton", "ArcaneBurnHelperMageArmorCheck", armorSection, "UICheckButtonTemplate")
    mageCheck:SetPoint("TOPLEFT", 18, -26)
    mageCheck.text:SetText("Mage")
    mageCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            ns.GetConfig().armorType = "MAGE"
            _G["ArcaneBurnHelperMoltenArmorCheck"]:SetChecked(false)
        else
            ns.GetConfig().armorType = "MOLTEN"
            _G["ArcaneBurnHelperMoltenArmorCheck"]:SetChecked(true)
        end
        if ns.RefreshDisplay then ns.RefreshDisplay() end
    end)

    local moltenCheck = CreateFrame("CheckButton", "ArcaneBurnHelperMoltenArmorCheck", armorSection, "UICheckButtonTemplate")
    moltenCheck:SetPoint("TOPLEFT", mageCheck, "BOTTOMLEFT", 0, -6)
    moltenCheck.text:SetText("Molten")
    moltenCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            ns.GetConfig().armorType = "MOLTEN"
            _G["ArcaneBurnHelperMageArmorCheck"]:SetChecked(false)
        else
            ns.GetConfig().armorType = "MAGE"
            _G["ArcaneBurnHelperMageArmorCheck"]:SetChecked(true)
        end
        if ns.RefreshDisplay then ns.RefreshDisplay() end
    end)

    local cooldownSection = CreateSection(optionsPanel, "Cooldowns & Consumables", rightX, -160, sectionW, 138)
    local t5Check = CreateFrame("CheckButton", "ArcaneBurnHelperT5Check", cooldownSection, "UICheckButtonTemplate")
    t5Check:SetPoint("TOPLEFT", 2, -24)
    t5Check.text:SetText("T5 2pc")
    t5Check:SetScript("OnClick", function(self)
        ns.GetConfig().t5_2pc = self:GetChecked() and true or false
        if ns.RefreshDisplay then ns.RefreshDisplay() end
    end)

    local potionLabel = cooldownSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    potionLabel:SetPoint("TOPLEFT", 18, -54)
    potionLabel:SetText("Potion Type")

    local manaPotCheck = CreateFrame("CheckButton", "ArcaneBurnHelperManaPotCheck", cooldownSection, "UICheckButtonTemplate")
    manaPotCheck:SetPoint("TOPLEFT", 18, -72)
    manaPotCheck.text:SetText("Mana Potion")
    manaPotCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            ns.GetConfig().potionType = "MANA"
            _G["ArcaneBurnHelperDestroPotCheck"]:SetChecked(false)
        else
            ns.GetConfig().potionType = "DESTRO"
            _G["ArcaneBurnHelperDestroPotCheck"]:SetChecked(true)
        end
        if ns.RefreshDisplay then ns.RefreshDisplay() end
    end)

    local destroPotCheck = CreateFrame("CheckButton", "ArcaneBurnHelperDestroPotCheck", cooldownSection, "UICheckButtonTemplate")
    destroPotCheck:SetPoint("TOPLEFT", manaPotCheck, "BOTTOMLEFT", 0, -6)
    destroPotCheck.text:SetText("Destro Pot")
    destroPotCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            ns.GetConfig().potionType = "DESTRO"
            _G["ArcaneBurnHelperManaPotCheck"]:SetChecked(false)
        else
            ns.GetConfig().potionType = "MANA"
            _G["ArcaneBurnHelperManaPotCheck"]:SetChecked(true)
        end
        if ns.RefreshDisplay then ns.RefreshDisplay() end
    end)

    local lowManaSection = CreateSection(optionsPanel, "Low Mana Trigger", leftX, -218, sectionW, 122)
    local lowManaSlider = CreateSlider(lowManaSection, "ArcaneBurnHelperLowManaSlider", 5, 50, 1, 16, -36,
        function() return ns.GetConfig().lowManaPercent end,
        function(v) ns.GetConfig().lowManaPercent = v end,
        sliderW)
    lowManaSlider.labelPrefix = "Percent"
    StyleSliderBelow(lowManaSlider, true)

    local readySoonSection = CreateSection(optionsPanel, "Ready Soon Threshold", leftX, -356, sectionW, 122)
    local readySoonSlider = CreateSlider(readySoonSection, "ArcaneBurnHelperReadySoonSlider", 0, 30, 1, 16, -36,
        function() return ns.GetConfig().readySoonSeconds end,
        function(v) ns.GetConfig().readySoonSeconds = v end,
        sliderW)
    readySoonSlider.labelPrefix = "Seconds"
    StyleSliderBelow(readySoonSlider, true)

    local scaleSection = CreateSection(optionsPanel, "UI Scale", rightX, -314, sectionW, 122)
    local scaleSlider = CreateSlider(scaleSection, "ArcaneBurnHelperScaleSlider", 0.7, 2.5, 0.05, 16, -36,
        function() return ns.GetConfig().frameScale or 1.0 end,
        function(v)
            v = ns.Clamp(v, ns.CFG.minScale, ns.CFG.maxScale)
            ns.GetConfig().frameScale = tonumber(string.format("%.2f", v)) or v
            if ns.ApplyFrameScale then
                ns.ApplyFrameScale(ns.GetConfig().frameScale, true)
            end
        end,
        250,
        { formatter = function(v) return string.format("%.2f", v) end, round = false })
    scaleSlider.labelPrefix = "Scale"
    StyleSliderBelow(scaleSlider, true)

    local note = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("BOTTOMLEFT", 16, 12)
    note:SetText("Tip: use /abh lock to fully lock the frame, including scale handle.")

    optionsPanel.refresh = function()
        abSlider:Refresh()
        fbSlider:Refresh()
        mageCheck:SetChecked(ns.GetConfig().armorType == "MAGE")
        moltenCheck:SetChecked(ns.GetConfig().armorType ~= "MAGE")
        t5Check:SetChecked(ns.GetConfig().t5_2pc)
        manaPotCheck:SetChecked(ns.GetConfig().potionType == "MANA")
        destroPotCheck:SetChecked(ns.GetConfig().potionType ~= "MANA")
        lowManaSlider:Refresh()
        readySoonSlider:Refresh()
        scaleSlider:Refresh()
    end

    if ns.IsModernSettings() then
        settingsCategory = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
        Settings.RegisterAddOnCategory(settingsCategory)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(optionsPanel)
    end
end
