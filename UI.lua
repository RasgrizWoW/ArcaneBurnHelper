local addonName, ns = ...
ns = ns or _G.ArcaneBurnHelperNS

local frame = CreateFrame("Frame", "ArcaneBurnHelperFrame", UIParent)
ns.frame = frame

local cfg = ns.GetConfig()
frame:SetSize(cfg.frameWidth or ns.CFG.width, cfg.frameHeight or ns.CFG.height)
frame:SetScale(cfg.frameScale or 1.0)
frame:SetPoint(unpack(ns.CFG.defaultPoint))
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)

frame.bg = frame:CreateTexture(nil, "BACKGROUND")
frame.bg:SetAllPoints()
frame.bg:SetColorTexture(0, 0, 0, 0.45)

frame.border = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate")
frame.border:SetAllPoints()
if frame.border.SetBackdrop then
    frame.border:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame.border:SetBackdropColor(0, 0, 0, 0)
    frame.border:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
end

local function MakeCell(name, x, y, width, justify)
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(name)
    return fs
end

local leftWidth = 126
local rightX = 146
local rightWidth = 112
local startY = -10
local rowGap = -18

frame.row1ETK = MakeCell("ETK: --", 10, startY, leftWidth, "LEFT")
frame.row1Slow = MakeCell("S 20%: --", 10, startY + rowGap, leftWidth, "LEFT")
frame.row1Blow = MakeCell("B 20%: --", 10, startY + (rowGap * 2), leftWidth, "LEFT")
frame.row1Soom = MakeCell("S OOM: --", 10, startY + (rowGap * 3), leftWidth, "LEFT")
frame.row1Boom = MakeCell("B OOM: --", 10, startY + (rowGap * 4), leftWidth, "LEFT")
frame.row1Mode = MakeCell("Mode: HOLD", 10, startY + (rowGap * 5), leftWidth + 10, "LEFT")

frame.row2AB = MakeCell("AB0", rightX, startY, rightWidth, "LEFT")
frame.row2Armor = MakeCell("Armor: Molten", rightX, startY + rowGap, rightWidth, "LEFT")
frame.row2Evo = MakeCell("Evo", rightX, startY + (rowGap * 2), rightWidth, "LEFT")
frame.row2Gem = MakeCell("Gem", rightX, startY + (rowGap * 3), rightWidth, "LEFT")
frame.row2Pot = MakeCell("Pot", rightX, startY + (rowGap * 4), rightWidth, "LEFT")

frame.resizeHandle = CreateFrame("Button", nil, frame)
frame.resizeHandle:SetSize(16, 16)
frame.resizeHandle:SetPoint("BOTTOMRIGHT", -3, 3)
frame.resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
frame.resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
frame.resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
frame.scaleDrag = false

local function GetFrameBottomRight()
    return frame:GetRight(), frame:GetBottom()
end

local function SetFrameBottomRight(right, bottom)
    if not right or not bottom then return end
    local width = (cfg.frameWidth or ns.CFG.width) * (cfg.frameScale or 1.0)
    local height = (cfg.frameHeight or ns.CFG.height) * (cfg.frameScale or 1.0)
    local left = right - width
    local top = bottom + height
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    ArcaneBurnHelperDB.point = { "TOPLEFT", "UIParent", "BOTTOMLEFT", left, top }
end

local function ApplyScale(newScale, preserveBottomRight)
    newScale = ns.Clamp(newScale, ns.CFG.minScale, ns.CFG.maxScale)
    local right, bottom
    if preserveBottomRight then
        right, bottom = GetFrameBottomRight()
    end
    frame:SetScale(newScale)
    cfg.frameScale = tonumber(string.format("%.2f", newScale)) or newScale
    if preserveBottomRight then
        SetFrameBottomRight(right, bottom)
    end
end

local function ApplyScaleFromCursor()
    local right = frame:GetRight()
    local bottom = frame:GetBottom()
    if not right or not bottom then return end

    local cursorX, cursorY = GetCursorPosition()
    local effectiveScale = UIParent:GetEffectiveScale() or 1
    cursorX = cursorX / effectiveScale
    cursorY = cursorY / effectiveScale

    local desiredWidth = math.max(right - cursorX, 1)
    local desiredHeight = math.max(cursorY - bottom, 1)
    local scaleFromWidth = desiredWidth / (cfg.frameWidth or ns.CFG.width)
    local scaleFromHeight = desiredHeight / (cfg.frameHeight or ns.CFG.height)
    ApplyScale(math.max(scaleFromWidth, scaleFromHeight), true)
end

frame.resizeHandle:SetScript("OnMouseDown", function()
    if ns.GetConfig().locked then return end
    frame.scaleDrag = true
    ApplyScaleFromCursor()
end)
frame.resizeHandle:SetScript("OnMouseUp", function()
    if not frame.scaleDrag then return end
    frame.scaleDrag = false
    ApplyScaleFromCursor()
end)
frame.resizeHandle:SetScript("OnUpdate", function()
    if frame.scaleDrag and not ns.GetConfig().locked then
        ApplyScaleFromCursor()
    end
end)

frame:SetScript("OnDragStart", function(self)
    if not ns.GetConfig().locked then
        self:StartMoving()
    end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    ArcaneBurnHelperDB.point = { point, "UIParent", relativePoint, x, y }
end)

function ns.UpdateLockState()
    local locked = ns.GetConfig().locked
    if frame.resizeHandle then
        frame.resizeHandle:SetShown(not locked)
        frame.resizeHandle:EnableMouse(not locked)
    end
end

function ns.ApplyFrameScale(scale, preserveBottomRight)
    ApplyScale(scale or (cfg.frameScale or 1.0), preserveBottomRight)
end

ns.UpdateLockState()

function ns.SetABTextColor(stacks)
    if stacks <= 0 then
        frame.row2AB:SetTextColor(0.6, 0.6, 0.6)
    elseif stacks == 1 then
        frame.row2AB:SetTextColor(0.35, 0.65, 1.0)
    elseif stacks == 2 then
        frame.row2AB:SetTextColor(1.0, 0.85, 0.2)
    else
        frame.row2AB:SetTextColor(1.0, 0.45, 0.15)
    end
end

local function ColorState(word, state)
    if state == "ready" then
        return string.format("|cff00ff00%s|r", word)
    elseif state == "soon" then
        return string.format("|cffffd200%s|r", word)
    elseif state == "missing" then
        return string.format("|cff909090%s|r", word)
    end
    return string.format("|cffff4040%s|r", word)
end

function ns.UpdateCooldownCue(evoState, gemState, potionState)
    frame.row2Evo:SetText(ColorState("Evo", evoState))
    frame.row2Gem:SetText(ColorState("Gem", gemState))
    frame.row2Pot:SetText(ColorState("Pot", potionState))
end

function ns.UpdateModeText(mode)
    if mode == "BURN" then
        frame.row1Mode:SetText("|cff00ff00Mode: BURN|r")
    elseif mode == "SUSTAIN" then
        frame.row1Mode:SetText("|cffff4040Mode: SUSTAIN|r")
    else
        frame.row1Mode:SetText("|cff80c0ffMode: HOLD|r")
    end
end
