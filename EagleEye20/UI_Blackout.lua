local AddonName, ns = ...

local f, title, subText, countText, hintText, logo
local fade
local lastClick = 0

local function SetSolidColor(tex, r, g, b, a)
    if not tex then return end
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a or 1)
    else
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetVertexColor(r, g, b, a or 1)
    end
end

local function CancelBreakFromOverlay(reason)
    if ns.state == ns.RESTING then
        ns.AbortRest(reason)
    else
        -- Defensive: the overlay must never stay up when no break is running.
        if f then f:Hide() end
    end
end

local function CreateBlackout()
    f = ns.NewFrame("Frame", "EagleEye20Blackout", UIParent)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetAllPoints(UIParent)
    -- The overlay is only click-blocking while a break is actually running.
    -- Mouse and keyboard are enabled on show and disabled on hide so a stale or
    -- invisible overlay can never swallow clicks meant for the native UI.
    f:EnableMouse(false)
    if f.SetBackdrop then
        pcall(f.SetBackdrop, f, { bgFile = "Interface\\Buttons\\WHITE8X8" })
        pcall(f.SetBackdropColor, f, 0, 0, 0, 0.95)
    end

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    SetSolidColor(bg, 0, 0, 0, 0.95)
    f.bg = bg
    f:Hide()

    logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ns.MEDIA .. "Logo")
    logo:SetWidth(256)
    logo:SetHeight(256)
    logo:SetPoint("CENTER", f, "CENTER", 0, 190)
    logo:SetAlpha(0.95)

    title = f:CreateFontString(nil, "OVERLAY")
    title:SetPoint("CENTER", f, "CENTER", 0, 35)
    title:SetFont("Fonts\\FRIZQT__.TTF", 26, "OUTLINE")
    title:SetText("EAGLE EYE 20/20/20")
    title:SetTextColor(0.0, 0.8, 0.6, 1)

    subText = f:CreateFontString(nil, "OVERLAY")
    subText:SetPoint("TOP", title, "BOTTOM", 0, -10)
    subText:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    subText:SetText("LOOK 20 FEET AWAY")
    subText:SetTextColor(0.92, 0.92, 0.95, 1)

    countText = f:CreateFontString(nil, "OVERLAY")
    countText:SetPoint("CENTER", f, "CENTER", 0, -85)
    countText:SetFont("Fonts\\FRIZQT__.TTF", 96, "OUTLINE")
    countText:SetText("20")
    countText:SetTextColor(0.95, 0.65, 0.1, 1)

    hintText = f:CreateFontString(nil, "OVERLAY")
    hintText:SetPoint("BOTTOM", f, "BOTTOM", 0, 40)
    hintText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
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

    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            CancelBreakFromOverlay("Escape key")
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    f:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        local now = GetTime()
        if now - lastClick < 0.4 then
            lastClick = 0
            CancelBreakFromOverlay("Double-click")
        else
            lastClick = now
        end
    end)

    f:SetScript("OnHide", function()
        fade = nil
        lastClick = 0
        f:EnableMouse(false)
        if ns.state == ns.RESTING then
            ns.AbortRest("Closed")
        end
    end)

    table.insert(UISpecialFrames, "EagleEye20Blackout")

    ns.Blackout = f
end

local function StartFade(from, to, duration, onDone)
    if not f then return end
    f:SetAlpha(from)
    fade = { from = from, to = to, t = 0, duration = duration, onDone = onDone }
end

-- Fully dismisses the overlay: input off, alpha restored, fade cancelled.
-- Every exit path goes through this so the frame can never linger shown at
-- alpha 0 with the mouse still enabled, which would silently eat every click
-- on the native UI.
local function DismissNow()
    if not f then return end
    fade = nil
    lastClick = 0
    f:EnableMouse(false)
    f:EnableKeyboard(false)
    f:SetAlpha(1)
    if f:IsShown() then
        f:Hide()
    end
end

ns.DismissBlackout = DismissNow

function ns.ShowBlackout()
    if not f or not ns.db then return end
    local p = ns.db.profile
    local alpha = p.blackoutAlpha or 0.95
    if f.SetBackdropColor then
        pcall(f.SetBackdropColor, f, 0, 0, 0, alpha)
    end
    if f.bg then
        SetSolidColor(f.bg, 0, 0, 0, alpha)
    end
    subText:SetText("LOOK " .. tostring(p.distanceFeet or 20) .. " FEET AWAY")
    countText:SetText(tostring(math.max(0, math.ceil(ns.restTimer))))
    f:EnableMouse(true)
    f:EnableKeyboard(true)
    f:Show()
    StartFade(0, 1, 0.5)
end

function ns.HideBlackout()
    if not f then return end
    if not f:IsShown() then
        DismissNow()
        return
    end
    -- Stop accepting input immediately; the fade-out must never leave a
    -- click-blocking frame behind if the animation is interrupted.
    f:EnableMouse(false)
    f:EnableKeyboard(false)
    StartFade(f:GetAlpha() or 1, 0, 0.3, DismissNow)
end

-- Safety net: the overlay is a fullscreen, mouse-enabled frame. If any path
-- leaves it shown outside a break (a missed event, an aborted fade, an addon
-- error), the player would be unable to click any native UI. This runs on a
-- light timer and force-closes it any time no break is active.
local guardAccum = 0
local guard = CreateFrame("Frame", "EagleEye20BlackoutGuard", UIParent)
guard:SetScript("OnUpdate", function(_, elapsed)
    guardAccum = guardAccum + elapsed
    if guardAccum < 1 then return end
    guardAccum = 0
    if not f then return end
    if ns.state ~= ns.RESTING then
        if f:IsShown() or f:GetAlpha() ~= 1 then
            DismissNow()
        end
        return
    end
    -- A break is running, so the overlay must be up and clickable.
    if not f:IsShown() then
        ns.ShowBlackout()
    end
end)

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
