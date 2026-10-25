local AddonName, ns = ...

local f, title, subText, countText, hintText
local fade
local lastClick = 0

local function CreateBlackout()
    f = CreateFrame("Frame", "EagleEye20Blackout", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetAllPoints(UIParent)
    f:EnableMouse(true)
    f:EnableKeyboard(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    f:SetBackdropColor(0, 0, 0, 0.95)
    f:Hide()

    title = f:CreateFontString(nil, "OVERLAY")
    title:SetPoint("CENTER", f, "CENTER", 0, 120)
    title:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    title:SetText("EAGLE EYE 20/20/20")
    title:SetTextColor(0.0, 0.8, 0.6, 1)

    subText = f:CreateFontString(nil, "OVERLAY")
    subText:SetPoint("TOP", title, "BOTTOM", 0, -14)
    subText:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    subText:SetText("LOOK 20 FEET AWAY")
    subText:SetTextColor(0.92, 0.92, 0.95, 1)

    countText = f:CreateFontString(nil, "OVERLAY")
    countText:SetPoint("CENTER", f, "CENTER", 0, 10)
    countText:SetFont("Fonts\\FRIZQT__.TTF", 84, "OUTLINE")
    countText:SetText("20")
    countText:SetTextColor(0.95, 0.65, 0.1, 1)

    hintText = f:CreateFontString(nil, "OVERLAY")
    hintText:SetPoint("BOTTOM", f, "BOTTOM", 0, 40)
    hintText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    hintText:SetText("Double-click anywhere or press ESC to emergency cancel (Auto-cancels on combat)")
    hintText:SetTextColor(0.6, 0.6, 0.66, 0.75)

    f:SetScript("OnUpdate", function(self, elapsed)
        if fade then
            fade.t = fade.t + elapsed
            local fraction = fade.t / fade.duration
            if fraction >= 1 then
                fraction = 1
            end
            self:SetAlpha(fade.from + (fade.to - fade.from) * fraction)
            if fraction >= 1 then
                local done = fade.onDone
                fade = nil
                if done then done() end
            end
        end
        if self:IsShown() and ns.state == ns.RESTING and ns.db then
            countText:SetText(tostring(math.max(0, math.ceil(ns.restTimer))))
        end
    end)

    f:SetScript("OnMouseUp", function(_, button)
        local now = GetTime()
        if now - lastClick < 0.4 then
            lastClick = 0
            ns.AbortRest("Double-click")
        else
            lastClick = now
        end
    end)

    f:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            ns.AbortRest("Escape key")
            if GameMenuFrame and GameMenuFrame:IsShown() then
                GameMenuFrame:Hide()
            end
        end
    end)

    f:SetScript("OnHide", function()
        fade = nil
        lastClick = 0
        if ns.state == ns.RESTING then
            ns.AbortRest("Closed")
        end
    end)

    tinsert(UISpecialFrames, "EagleEye20Blackout")

    ns.Blackout = f
end

local function StartFade(from, to, duration, onDone)
    if not f then return end
    f:SetAlpha(from)
    fade = { from = from, to = to, t = 0, duration = duration, onDone = onDone }
end

function ns.ShowBlackout()
    if not f or not ns.db then return end
    local p = ns.db.profile
    f:SetBackdropColor(0, 0, 0, p.blackoutAlpha or 0.95)
    subText:SetText("LOOK " .. tostring(p.distanceFeet or 20) .. " FEET AWAY")
    countText:SetText(tostring(math.max(0, math.ceil(ns.restTimer))))
    f:Show()
    StartFade(0, 1, 0.5)
end

function ns.HideBlackout()
    if not f then return end
    if not f:IsShown() then return end
    StartFade(f:GetAlpha() or 1, 0, 0.3, function()
        f:Hide()
    end)
end

ns.RegisterInit(function()
    CreateBlackout()

    ns.On("BreakStart", function()
        ns.ShowBlackout()
    end)
    ns.On("BreakEnd", function()
        ns.HideBlackout()
    end)
    ns.On("BreakInterrupted", function()
        ns.HideBlackout()
    end)
    ns.On("BreakAborted", function()
        ns.HideBlackout()
    end)
    ns.On("TimersChanged", function()
        if f and f:IsShown() and ns.db then
            subText:SetText("LOOK " .. tostring(ns.db.profile.distanceFeet or 20) .. " FEET AWAY")
        end
    end)
end)
