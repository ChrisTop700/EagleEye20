local AddonName, ns = ...

local WIDTH, HEIGHT = 140, 42
local EXPANDED_HEIGHT = 64
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
    if not ns.db or not fontString then return end
    local p = ns.db.profile
    local outline = p.fontOutline
    if outline == "" or outline == "NONE" then outline = nil end
    local path = p.fontFace
    if not path or path == "" then path = "Fonts\\FRIZQT__.TTF" end
    local ok = pcall(fontString.SetFont, fontString, path, size or p.fontSize or 16, outline or "")
    if not ok then
        pcall(fontString.SetFont, fontString, "Fonts\\FRIZQT__.TTF", size or p.fontSize or 16, outline or "")
    end
end

local function MakeTip()
    tip = ns.NewFrame("Frame", "EagleEye20WidgetTip", UIParent)
    tip:SetFrameStrata("TOOLTIP")
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
    tip.text:SetPoint("LEFT", tip, "LEFT", 6, 0)
    tip.text:SetPoint("RIGHT", tip, "RIGHT", -6, 0)
    tip:Hide()
end

local function ShowTip(owner, text)
    if not tip then MakeTip() end
    tip.text:SetText(text)
    tip:SetWidth(tip.text:GetStringWidth() + 14)
    tip:SetHeight(20)
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOMRIGHT", owner, "TOPLEFT", -2, 2)
    tip:Show()
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
        pcall(b.SetBackdropColor, b, 0.16, 0.16, 0.20, 1.0)
        pcall(b.SetBackdropBorderColor, b, 0.30, 0.30, 0.35, 1.0)
    end

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    SetSolidColor(bg, 0.16, 0.16, 0.20, 1.0)
    b.bg = bg

    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetText(label)
    b.label:SetTextColor(0.85, 0.85, 0.90)

    b:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then pcall(self.SetBackdropColor, self, 0.24, 0.24, 0.29, 1.0) end
        SetSolidColor(self.bg, 0.24, 0.24, 0.29, 1.0)
        if tooltipText and tooltipText ~= "" then
            ShowTip(self, tooltipText)
        end
    end)
    b:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then pcall(self.SetBackdropColor, self, 0.16, 0.16, 0.20, 1.0) end
        SetSolidColor(self.bg, 0.16, 0.16, 0.20, 1.0)
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
    f = ns.NewFrame("Frame", "EagleEye20Widget", UIParent)
    f:SetWidth(WIDTH)
    f:SetHeight(HEIGHT)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    if f.SetBackdrop then
        pcall(f.SetBackdrop, f, {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        pcall(f.SetBackdropColor, f, 0.08, 0.08, 0.10, 0.88)
        pcall(f.SetBackdropBorderColor, f, 0.25, 0.25, 0.30, 1.0)
    end

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    SetSolidColor(bg, 0.08, 0.08, 0.10, 0.90)
    f.bg = bg

    local borders = {}
    local function MakeLine(p1, r1, p2, r2, w, h)
        local line = f:CreateTexture(nil, "OVERLAY")
        line:SetPoint(p1, f, r1, 0, 0)
        line:SetPoint(p2, f, r2, 0, 0)
        if w then line:SetWidth(w) end
        if h then line:SetHeight(h) end
        SetSolidColor(line, 0.25, 0.25, 0.30, 1.0)
        table.insert(borders, line)
    end
    MakeLine("TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT", nil, 1)
    MakeLine("BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT", nil, 1)
    MakeLine("TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT", 1, nil)
    MakeLine("TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT", 1, nil)
    f.borders = borders
    f:Hide()

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
        p.widgetPoint = point
        p.widgetRelPoint = relPoint
        p.widgetX = math.floor(x + 0.5)
        p.widgetY = math.floor(y + 0.5)
    end)
    f:SetScript("OnEnter", function(self)
        ShowTip(self, "Eagle Eye 20/20/20 - drag to move. Type /ee20 for options.")
    end)
    f:SetScript("OnLeave", HideTip)

    headerIcon = f:CreateTexture(nil, "ARTWORK")
    headerIcon:SetTexture(ns.MEDIA .. "IconRound")
    headerIcon:SetWidth(11)
    headerIcon:SetHeight(11)
    headerIcon:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)

    headerText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    headerText:SetPoint("TOPLEFT", f, "TOPLEFT", 17, -4)
    headerText:SetText("EAGLE EYE")
    headerText:SetFont("Fonts\\FRIZQT__.TTF", 7, "")
    headerText:SetTextColor(0.62, 0.63, 0.68, 0.9)

    logBtn = MakeButton(f, "LOG", 22, 12, "Event log and statistics", function()
        if ns.ToggleLog then ns.ToggleLog() end
    end)
    logBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -3)

    resetBtn = MakeButton(f, "RST", 22, 12, "Reset the work timer", function()
        ns.ResetTimer()
    end)
    resetBtn:SetPoint("TOPRIGHT", logBtn, "TOPLEFT", -2, 0)

    pauseBtn = MakeButton(f, "II", 18, 12, "Pause or resume the timer", function()
        if ns.state == ns.PAUSED then
            ns.ResumeTimer()
        else
            ns.PauseTimer()
        end
    end)
    pauseBtn:SetPoint("TOPRIGHT", resetBtn, "TOPLEFT", -2, 0)

    countText = f:CreateFontString(nil, "OVERLAY")
    countText:SetPoint("TOP", f, "TOP", 0, -16)
    countText:SetText("20:00")
    countText:SetTextColor(0, 0.8, 0.6)
    countText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    f.countText = countText

    barTrack = f:CreateTexture(nil, "ARTWORK")
    SetSolidColor(barTrack, 0.25, 0.25, 0.30, 0.35)
    barTrack:SetHeight(2)
    barTrack:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    barTrack:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

    barFill = f:CreateTexture(nil, "OVERLAY")
    SetSolidColor(barFill, 0, 0.8, 0.6, 1)
    barFill:SetHeight(2)
    barFill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    barFill:SetWidth(WIDTH - 2)

    combatText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    combatText:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    combatText:SetText("IN COMBAT - WAITING")
    combatText:SetTextColor(0.9, 0.25, 0.25)
    combatText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    combatText:Hide()

    safeBtn = MakeButton(f, "SAFE NOW", 60, 18, "Confirm you are safe and start the break", function()
        if ns.ConfirmSafe(taxiPrompt) then
            taxiPrompt = false
        end
    end)
    safeBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 5)

    snooze1Btn = MakeButton(f, "+1M", 34, 18, "Snooze the break by one minute", function()
        ns.Snooze(60)
    end)
    snooze1Btn:SetPoint("BOTTOMLEFT", safeBtn, "BOTTOMRIGHT", 3, 0)

    snooze2Btn = MakeButton(f, "+2M", 34, 18, "Snooze the break by two minutes", function()
        ns.Snooze(120)
    end)
    snooze2Btn:SetPoint("BOTTOMLEFT", snooze1Btn, "BOTTOMRIGHT", 3, 0)

    f:SetScript("OnUpdate", function(_, elapsed)
        if not ns.db then return end
        if ns.state == ns.READY_WAITING then
            pulse = pulse + elapsed
            local color = ns.COLORS[ns.READY_WAITING]
            local alpha = 0.45 + 0.55 * math.abs(math.sin(pulse * 3))
            SetWidgetBorderColor(color.r, color.g, color.b, alpha)
        else
            pulse = 0
            SetWidgetBorderColor(0.25, 0.25, 0.30, 1.0)
        end
    end)
end

local function ApplyLayout()
    if not f or not ns.db then return end
    local p = ns.db.profile
    if not p.enabled or (p.showWidget == false) then
        f:Hide()
        return
    end
    f:ClearAllPoints()
    f:SetPoint(p.widgetPoint or "CENTER", UIParent, p.widgetRelPoint or "CENTER", p.widgetX or 0, p.widgetY or 260)
    f:SetScale(p.widgetScale or 1)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    ApplyFont(countText, p.fontSize)
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
    f:Show()
    f:Raise()

    local state = ns.state
    local color = ns.COLORS[state] or ns.COLORS.PAUSED
    local combat = ns.InCombat()

    local remaining = ns.timeRemaining
    if state == ns.RESTING then
        remaining = ns.restTimer
    end
    countText:SetText(ns.FormatTime(remaining))
    countText:SetTextColor(color.r, color.g, color.b)

    local fraction
    if state == ns.RESTING then
        fraction = 1 - (ns.restTimer / math.max(1, p.restDuration))
    else
        fraction = 1 - (ns.timeRemaining / math.max(1, p.workDuration))
    end
    fraction = math.max(0, math.min(1, fraction))
    barFill:SetWidth(math.max(1, math.floor((WIDTH - BAR_INSET * 2) * fraction + 0.5)))
    SetSolidColor(barFill, color.r, color.g, color.b, 1)

    pauseBtn.label:SetText(state == ns.PAUSED and ">" or "II")

    local showSafe = (state == ns.PREPARE or state == ns.READY_WAITING or (taxiPrompt and state == ns.RUNNING))
    local showSnooze = (state == ns.PREPARE or state == ns.READY_WAITING)
    local waitingCombat = (state == ns.READY_WAITING and combat)

    if state == ns.RESTING then
        showSafe = false
        showSnooze = false
    end

    if taxiPrompt and state == ns.RUNNING then
        safeBtn.label:SetText("BREAK NOW")
    else
        safeBtn.label:SetText("SAFE NOW")
    end

    if showSafe then
        safeBtn:Show()
    else
        safeBtn:Hide()
    end

    if waitingCombat then
        safeBtn:Hide()
        snooze1Btn:Hide()
        snooze2Btn:Hide()
        combatText:Show()
    else
        combatText:Hide()
    end

    if showSnooze and not waitingCombat then
        snooze1Btn:Show()
        snooze2Btn:Show()
    else
        snooze1Btn:Hide()
        snooze2Btn:Hide()
    end

    local expanded = showSafe or showSnooze or waitingCombat
    f:SetHeight(expanded and EXPANDED_HEIGHT or HEIGHT)

    if taxiPrompt then
        headerText:SetText("TAKE BREAK NOW?")
        headerText:SetTextColor(0.95, 0.65, 0.1, 1)
    else
        headerText:SetText("EAGLE EYE")
        headerText:SetTextColor(0.62, 0.63, 0.68, 0.9)
    end
end

ns.RegisterInit(function()
    CreateWidget()
    ns.ApplyWidgetSettings = ApplyLayout
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

    ns.Widget = f
end)
