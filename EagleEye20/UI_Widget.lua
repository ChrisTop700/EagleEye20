local AddonName, ns = ...

local WIDTH, HEIGHT = 180, 52
local EXPANDED_HEIGHT = 76
local BAR_INSET = 2

local f
local countText, headerText, combatText, headerIcon
local barTrack, barFill
local pauseBtn, resetBtn, logBtn
local safeBtn, snooze1Btn, snooze2Btn
local tip

local taxiPrompt = false
local pulse = 0

local function SetSolidColor(tex, r, g, b, a)
    if not tex then return end
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a or 1)
    else
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetVertexColor(r, g, b, a or 1)
    end
end

local function ApplyFont(fontString, size)
    if not fontString then return end
    local p = ns.db and ns.db.profile
    local s = size or (p and p.fontSize) or 20
    local outline = p and p.fontOutline
    if outline == "" or outline == "NONE" then outline = "" end
    local path = p and p.fontFace or "Fonts\\FRIZQT__.TTF"

    local ok = pcall(fontString.SetFont, fontString, path, s, outline or "")
    if not ok or not fontString:GetFont() then
        pcall(fontString.SetFontObject, fontString, "GameFontNormalLarge")
        local curPath = fontString:GetFont()
        if curPath then
            pcall(fontString.SetFont, fontString, curPath, s, outline or "")
        end
    end
end

local function UpdateTipPosition()
    if not tip or not tip:IsShown() then return end
    local curX, curY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    local x = curX / scale
    local y = curY / scale

    local w = tip:GetWidth() or 120
    local h = tip:GetHeight() or 22
    local screenW = UIParent:GetWidth() or 1920
    local screenH = UIParent:GetHeight() or 1080

    -- Offset from cursor so cursor does not obscure text
    local posX = x + 12
    local posY = y - 12

    -- Horizontal clamping / flip
    if posX + w > screenW - 8 then
        posX = x - w - 8
    end
    if posX < 8 then
        posX = 8
    end

    -- Vertical clamping / flip
    if posY - h < 8 then
        posY = y + h + 12
    end
    if posY > screenH - 8 then
        posY = screenH - 8
    end

    tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", posX, posY)
end

local function MakeTip()
    tip = ns.NewFrame("Frame", "EagleEye20WidgetTip", UIParent)
    tip:SetFrameStrata("TOOLTIP")
    tip:SetClampedToScreen(true)
    tip:EnableMouse(false)
    if tip.SetBackdrop then
        pcall(tip.SetBackdrop, tip, {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        pcall(tip.SetBackdropColor, tip, 0.08, 0.08, 0.10, 0.95)
        pcall(tip.SetBackdropBorderColor, tip, 0.25, 0.25, 0.30, 1.0)
    end
    local bg = tip:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(tip)
    SetSolidColor(bg, 0.08, 0.08, 0.10, 0.95)
    tip.bg = bg

    tip.text = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tip.text:SetPoint("LEFT", tip, "LEFT", 8, 0)
    tip.text:SetPoint("RIGHT", tip, "RIGHT", -8, 0)

    tip:SetScript("OnUpdate", UpdateTipPosition)
    tip:Hide()
end

local function ShowTip(owner, text)
    if not tip then MakeTip() end
    tip.text:SetText(text)
    tip:SetWidth(tip.text:GetStringWidth() + 18)
    tip:SetHeight(22)
    tip:Show()
    UpdateTipPosition()
end

local function HideTip()
    if tip then tip:Hide() end
end

local function MakeButton(parent, label, width, height, tooltipText, onClick)
    local b = ns.NewFrame("Button", nil, parent)
    b:SetWidth(width)
    b:SetHeight(height)
    if b.SetBackdrop then
        pcall(b.SetBackdrop, b, {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        pcall(b.SetBackdropColor, b, 0.14, 0.16, 0.20, 1.0)
        pcall(b.SetBackdropBorderColor, b, 0.30, 0.35, 0.40, 1.0)
    end

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    SetSolidColor(bg, 0.14, 0.16, 0.20, 1.0)
    b.bg = bg

    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetText(label)
    b.label:SetTextColor(0.85, 0.88, 0.92)

    b:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then pcall(self.SetBackdropColor, self, 0.22, 0.26, 0.32, 1.0) end
        SetSolidColor(self.bg, 0.22, 0.26, 0.32, 1.0)
        if tooltipText and tooltipText ~= "" then
            ShowTip(self, tooltipText)
        end
    end)
    b:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then pcall(self.SetBackdropColor, self, 0.14, 0.16, 0.20, 1.0) end
        SetSolidColor(self.bg, 0.14, 0.16, 0.20, 1.0)
        HideTip()
    end)
    b:SetScript("OnClick", onClick)

    return b
end

local function SetWidgetBorderColor(r, g, b, a)
    if not f then return end
    if f.SetBackdropBorderColor then
        pcall(f.SetBackdropBorderColor, f, r, g, b, a or 1)
    end
    if f.borders then
        for _, line in ipairs(f.borders) do
            SetSolidColor(line, r, g, b, a or 1)
        end
    end
end

local function CreateWidget()
    if f then return f end

    f = CreateFrame("Frame", "EagleEye20Widget", UIParent)
    ns.Widget = f
    _G["EagleEye20Widget"] = f

    f:SetWidth(WIDTH)
    f:SetHeight(HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(100)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)

    if f.SetBackdrop then
        pcall(f.SetBackdrop, f, {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        pcall(f.SetBackdropColor, f, 0.06, 0.08, 0.12, 0.94)
        pcall(f.SetBackdropBorderColor, f, 0.00, 0.80, 0.60, 1.0)
    end

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    SetSolidColor(bg, 0.06, 0.08, 0.12, 0.94)
    f.bg = bg

    local borders = {}
    local function MakeLine(p1, r1, p2, r2, w, h)
        local line = f:CreateTexture(nil, "BORDER")
        line:SetPoint(p1, f, r1, 0, 0)
        line:SetPoint(p2, f, r2, 0, 0)
        if w then line:SetWidth(w) end
        if h then line:SetHeight(h) end
        SetSolidColor(line, 0.00, 0.80, 0.60, 1.0)
        table.insert(borders, line)
    end
    MakeLine("TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT", nil, 2)
    MakeLine("BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT", nil, 2)
    MakeLine("TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT", 2, nil)
    MakeLine("TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT", 2, nil)
    f.borders = borders

    f:SetScript("OnDragStart", function(self)
        if ns.db and not ns.db.profile.locked then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not ns.db then return end
        local point, _, relPoint, x, y = self:GetPoint()
        local p = ns.db.profile
        p.widgetPoint = point or "CENTER"
        p.widgetRelPoint = relPoint or "CENTER"
        p.widgetX = math.floor((x or 0) + 0.5)
        p.widgetY = math.floor((y or 0) + 0.5)
    end)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            if ns.OpenConfig then
                ns.OpenConfig()
            end
        end
    end)
    f:SetScript("OnEnter", function(self)
        ShowTip(self, "Eagle Eye 20/20/20 | Drag: Move | Right-click: Options")
    end)
    f:SetScript("OnLeave", HideTip)

    headerIcon = f:CreateTexture(nil, "ARTWORK")
    headerIcon:SetTexture(ns.MEDIA .. "IconRound")
    headerIcon:SetWidth(12)
    headerIcon:SetHeight(12)
    headerIcon:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -5)

    headerText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    headerText:SetPoint("TOPLEFT", f, "TOPLEFT", 21, -5)
    headerText:SetText("EAGLE EYE")
    headerText:SetTextColor(0.85, 0.85, 0.90, 0.95)

    logBtn = MakeButton(f, "LOG", 24, 13, "Event log and statistics", function()
        if ns.ToggleLog then ns.ToggleLog() end
    end)
    logBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -4)

    resetBtn = MakeButton(f, "RST", 24, 13, "Reset the work timer", function()
        ns.ResetTimer()
    end)
    resetBtn:SetPoint("TOPRIGHT", logBtn, "TOPLEFT", -2, 0)

    pauseBtn = MakeButton(f, "II", 20, 13, "Pause or resume the timer", function()
        if ns.state == ns.PAUSED then
            ns.ResumeTimer()
        else
            ns.PauseTimer()
        end
    end)
    pauseBtn:SetPoint("TOPRIGHT", resetBtn, "TOPLEFT", -2, 0)

    countText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    countText:SetPoint("CENTER", f, "CENTER", 0, -2)
    countText:SetText("20:00")
    countText:SetTextColor(0.0, 0.85, 0.65)
    ApplyFont(countText, 20)
    f.countText = countText

    barTrack = f:CreateTexture(nil, "ARTWORK")
    SetSolidColor(barTrack, 0.25, 0.25, 0.30, 0.40)
    barTrack:SetHeight(3)
    barTrack:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 2)
    barTrack:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)

    barFill = f:CreateTexture(nil, "OVERLAY")
    SetSolidColor(barFill, 0.0, 0.85, 0.65, 1)
    barFill:SetHeight(3)
    barFill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 2)
    barFill:SetWidth(WIDTH - 4)

    combatText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    combatText:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    combatText:SetText("IN COMBAT - WAITING")
    combatText:SetTextColor(0.95, 0.30, 0.30)
    combatText:Hide()

    safeBtn = MakeButton(f, "SAFE NOW", 68, 18, "Confirm you are safe and start the break", function()
        if ns.ConfirmSafe(taxiPrompt) then
            taxiPrompt = false
        end
    end)
    safeBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 5, 6)

    snooze1Btn = MakeButton(f, "+1M", 42, 18, "Snooze the break by one minute", function()
        ns.Snooze(60)
    end)
    snooze1Btn:SetPoint("BOTTOMLEFT", safeBtn, "BOTTOMRIGHT", 4, 0)

    snooze2Btn = MakeButton(f, "+2M", 42, 18, "Snooze the break by two minutes", function()
        ns.Snooze(120)
    end)
    snooze2Btn:SetPoint("BOTTOMLEFT", snooze1Btn, "BOTTOMRIGHT", 4, 0)

    f:SetScript("OnUpdate", function(_, elapsed)
        if not ns.db then return end
        if ns.state == ns.READY_WAITING then
            pulse = pulse + elapsed
            local color = ns.COLORS[ns.READY_WAITING]
            local alpha = 0.45 + 0.55 * math.abs(math.sin(pulse * 3))
            SetWidgetBorderColor(color.r, color.g, color.b, alpha)
        else
            pulse = 0
            SetWidgetBorderColor(0.00, 0.80, 0.60, 1.0)
        end
    end)

    f:Hide()
    return f
end

local function ApplyLayout()
    if not f or not ns.db then return end
    local p = ns.db.profile
    if not p.enabled or (p.showWidget == false) then
        f:Hide()
        return
    end
    f:ClearAllPoints()
    f:SetPoint(p.widgetPoint or "CENTER", UIParent, p.widgetRelPoint or "CENTER", p.widgetX or 0, p.widgetY or 0)
    f:SetScale(p.widgetScale or 1)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(100)
    ApplyFont(countText, p.fontSize or 20)
    f:Show()
    f:Raise()
end

local function Update()
    if not f or not ns.db then return end
    local p = ns.db.profile

    if not p.enabled or (p.showWidget == false) then
        f:Hide()
        return
    end
    if not f:IsShown() then
        f:Show()
    end

    local state = ns.state or ns.RUNNING
    local color = ns.COLORS[state] or ns.COLORS.PAUSED
    local combat = ns.InCombat and ns.InCombat() or false

    local remaining = ns.timeRemaining or 0
    if state == ns.RESTING then
        remaining = ns.restTimer or 0
    end
    countText:SetText(ns.FormatTime(remaining))
    countText:SetTextColor(color.r, color.g, color.b)

    local fraction = 0
    if state == ns.RESTING then
        local rest = math.max(1, p.restDuration or 20)
        fraction = 1 - ((ns.restTimer or 0) / rest)
    else
        local work = math.max(1, p.workDuration or 1200)
        fraction = 1 - ((ns.timeRemaining or 0) / work)
    end
    fraction = math.max(0, math.min(1, fraction))
    barFill:SetWidth(math.max(1, math.floor((WIDTH - 4) * fraction + 0.5)))
    SetSolidColor(barFill, color.r, color.g, color.b, 1)

    if pauseBtn and pauseBtn.label then
        pauseBtn.label:SetText(state == ns.PAUSED and ">" or "II")
    end

    local showSafe = (state == ns.PREPARE or state == ns.READY_WAITING or (taxiPrompt and state == ns.RUNNING))
    local showSnooze = (state == ns.PREPARE or state == ns.READY_WAITING)
    local waitingCombat = (state == ns.READY_WAITING and combat)

    if state == ns.RESTING then
        showSafe = false
        showSnooze = false
    end

    if safeBtn and safeBtn.label then
        if taxiPrompt and state == ns.RUNNING then
            safeBtn.label:SetText("BREAK NOW")
        else
            safeBtn.label:SetText("SAFE NOW")
        end
        if showSafe and not waitingCombat then
            safeBtn:Show()
        else
            safeBtn:Hide()
        end
    end

    if combatText then
        if waitingCombat then
            combatText:Show()
        else
            combatText:Hide()
        end
    end

    if snooze1Btn and snooze2Btn then
        if showSnooze and not waitingCombat then
            snooze1Btn:Show()
            snooze2Btn:Show()
        else
            snooze1Btn:Hide()
            snooze2Btn:Hide()
        end
    end

    local expanded = showSafe or showSnooze or waitingCombat
    f:SetHeight(expanded and EXPANDED_HEIGHT or HEIGHT)

    if headerText then
        if taxiPrompt then
            headerText:SetText("TAKE BREAK NOW?")
            headerText:SetTextColor(0.95, 0.65, 0.1, 1)
        else
            headerText:SetText("EAGLE EYE")
            headerText:SetTextColor(0.85, 0.85, 0.90, 0.95)
        end
    end
end

-- Create the frame immediately so ns.Widget is NEVER nil
CreateWidget()
ns.ApplyWidgetSettings = ApplyLayout

ns.RegisterInit(function()
    ApplyLayout()
    Update()

    ns.On("Tick", Update)
    ns.On("StateChanged", Update)
    ns.On("TimersChanged", Update)
    ns.On("SettingsChanged", function()
        ApplyLayout()
        Update()
    end)
    ns.On("CombatStart", Update)
    ns.On("CombatEnd", Update)
    ns.On("TaxiPrompt", function()
        taxiPrompt = true
        Update()
    end)
    ns.On("TaxiEnd", function()
        taxiPrompt = false
        Update()
    end)
end)
