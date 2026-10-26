local AddonName, ns = ...

local BUTTON_SIZE = 31
local ICON_INSET = 7
local ICON_SIZE = 18
local ICON_TEXTURE = ns.MEDIA .. "IconRound"

local MINIMAP_SHAPES = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local button

local function NormalizeAngle(angle)
    angle = tonumber(angle) or 250
    angle = angle % 360
    if angle < 0 then angle = angle + 360 end
    return angle
end

local function MinimapShape()
    local p = ns.db and ns.db.profile
    local setting = p and p.minimapShape or "AUTO"
    if setting ~= "AUTO" then
        return setting
    end
    if GetMinimapShape then
        local ok, shape = pcall(GetMinimapShape)
        if ok and type(shape) == "string" and shape ~= "" then return shape end
    end
    if _G["LeaPlusDB"] and _G["LeaPlusDB"]["SquareMinimap"] == "On" then
        return "SQUARE"
    end
    if _G["ElvUI"] or _G["Tukui"] then
        return "SQUARE"
    end
    return "ROUND"
end

local function PlaceButton()
    if not button or not Minimap then return end
    if button:GetParent() ~= Minimap then return end

    local p = ns.db and ns.db.profile
    local angle = math.rad(NormalizeAngle(p and p.minimapAngle))
    local x, y = math.cos(angle), math.sin(angle)
    local quadrant = 1
    if x < 0 then quadrant = quadrant + 1 end
    if y > 0 then quadrant = quadrant + 2 end

    local shape = MinimapShape()
    local isRound = (shape == "ROUND")
    local quadTable = MINIMAP_SHAPES[shape] or (isRound and MINIMAP_SHAPES.ROUND or MINIMAP_SHAPES.SQUARE)
    local gap = isRound and 2 or (BUTTON_SIZE / 2 + 2)
    local w = (Minimap:GetWidth() or 140) / 2 + gap
    local h = (Minimap:GetHeight() or 140) / 2 + gap

    if isRound or quadTable[quadrant] then
        x, y = x * w, y * h
    else
        local m = math.max(math.abs(x), math.abs(y))
        if m > 0 then x, y = x / m, y / m end
        x, y = x * w, y * h
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function StatusLine()
    local state = ns.state
    if state == ns.RUNNING then
        return "Working - " .. ns.FormatTime(ns.timeRemaining)
    elseif state == ns.PREPARE then
        return "Break soon - " .. ns.FormatTime(ns.timeRemaining)
    elseif state == ns.READY_WAITING then
        return "Break due - confirm you are safe"
    elseif state == ns.RESTING then
        return "Eye break - " .. ns.FormatTime(ns.restTimer)
    end
    return "Timer paused"
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Eagle Eye 20/20/20 |cff888888v" .. (ns.version or "0.20.0-alpha-wotlk") .. "|r", 0, 0.8, 0.6)
    GameTooltip:AddLine(StatusLine(), 0.9, 0.9, 0.92)
    GameTooltip:AddLine("Left-click: options", 0.65, 0.65, 0.7)
    GameTooltip:AddLine("Right-click: pause / resume", 0.65, 0.65, 0.7)
    GameTooltip:AddLine("Drag: move around the minimap", 0.65, 0.65, 0.7)
    GameTooltip:Show()
end

local function CreateButton()
    if button or not Minimap then return end

    button = CreateFrame("Button", "EagleEye20MinimapButton", Minimap)
    button:SetWidth(BUTTON_SIZE)
    button:SetHeight(BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetWidth(ICON_SIZE + 2)
    background:SetHeight(ICON_SIZE + 2)
    background:SetPoint("TOPLEFT", ICON_INSET, -5)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetWidth(ICON_SIZE)
    button.icon:SetHeight(ICON_SIZE)
    button.icon:SetPoint("TOPLEFT", ICON_INSET, -6)
    button.icon:SetTexture(ICON_TEXTURE)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(53)
    border:SetHeight(53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if ns.state == ns.PAUSED then
                ns.ResumeTimer()
            else
                ns.PauseTimer()
            end
        elseif ns.OpenConfig then
            ns.OpenConfig()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function()
            if not ns.db or not Minimap then return end
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            if not (mx and my and cx and cy) then return end
            ns.db.profile.minimapAngle = ns.RotatePoint(mx, my, cx / scale, cy / scale)
            PlaceButton()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
        ns.Fire("SettingsChanged")
    end)

    ns.MinimapButton = button
end

local function Refresh()
    if not button then
        CreateButton()
        if not button then return end
    end

    local p = ns.db and ns.db.profile
    if not p or not p.showMinimap then
        button:Hide()
        return
    end

    button:Show()
    button.icon:SetAlpha(p.enabled and 1 or 0.45)
    PlaceButton()
end

ns.RegisterInit(function()
    CreateButton()
    ns.ApplyMinimapSettings = Refresh
    Refresh()

    ns.On("SettingsChanged", Refresh)
    ns.On("StateChanged", Refresh)

    local late = CreateFrame("Frame")
    late:RegisterEvent("PLAYER_LOGIN")
    late:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        Refresh()
    end)
end)

-- Note: the Addon Compartment hooks from the modern-client build are removed
-- here; 3.3.5a has no Addon Compartment. The minimap button and /ee20 open
-- the options panel instead.
