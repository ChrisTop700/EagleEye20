local AddonName, ns = ...

local PRESET_ITEMS = {}
for _, key in ipairs(ns.PRESET_ORDER) do
    table.insert(PRESET_ITEMS, { text = key, value = key })
end

local ABORT_ITEMS = {
    { text = "Pause at ready gate", value = "PAUSE" },
    { text = "Reset work timer", value = "RESET" },
}

local OUTLINE_ITEMS = {
    { text = "None", value = "NONE" },
    { text = "Outline", value = "OUTLINE" },
    { text = "Thick outline", value = "THICKOUTLINE" },
    { text = "Monochrome", value = "MONOCHROME" },
}

local FONT_ITEMS = {
    { text = "Friz Quadrata", value = "Fonts\\FRIZQT__.TTF" },
    { text = "Arial Narrow", value = "Fonts\\ARIALN.TTF" },
    { text = "Skurri", value = "Fonts\\skurri.ttf" },
    { text = "Morpheus", value = "Fonts\\MORPHEUS.TTF" },
}

local MINIMAP_SHAPE_ITEMS = {
    { text = "Auto-detect shape", value = "AUTO" },
    { text = "Round minimap", value = "ROUND" },
    { text = "Square minimap", value = "SQUARE" },
}

local OVERLAY_STYLE_ITEMS = {
    { text = "Solid Blackout", value = "SOLID" },
    { text = "Soft Dimming Vignette", value = "VIGNETTE" },
}

local READY_REPEAT_ITEMS = {
    { text = "Off (Play once)", value = 0 },
    { text = "Every 30 seconds", value = 30 },
    { text = "Every 60 seconds", value = 60 },
    { text = "Every 2 minutes", value = 120 },
}

local SOUND_ITEMS = {
    { text = "Raid Warning", value = "Sound\\Interface\\RaidWarning.wav" },
    { text = "Ready Check", value = "Sound\\Interface\\ReadyCheck.wav" },
    { text = "Map Ping", value = "Sound\\Interface\\MapPing.wav" },
    { text = "Level Up", value = "Sound\\Interface\\LevelUp.wav" },
    { text = "Alarm Clock", value = "Sound\\Interface\\AlarmClockWarning3.wav" },
    { text = "Tell / Whisper", value = "Sound\\Interface\\iTellMessage.wav" },
    { text = "PVP Queue Ready", value = "Sound\\Interface\\PVPThroughQueue.wav" },
    { text = "Auction Window", value = "Sound\\Interface\\AuctionWindowOpen.wav" },
    { text = "Error / Buzz", value = "Sound\\Interface\\Error.wav" },
    { text = "None (Mute)", value = "" },
}

local SetSolidColor = ns.SetSolidColor

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["EAGLEEYE20_CONFIRM_OVERWRITE"] = {
    text = "Key [%s] is already bound to:\n\"%s\"\n\nDo you want to overwrite it and bind to Safe Now?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(self)
        if self.applyFunc then
            self.applyFunc()
        end
    end,
    OnCancel = function(self)
        if self.cancelFunc then
            self.cancelFunc()
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

local function Profile()
    return ns.db and ns.db.profile
end

-- Blizzard template names differ between builds; try each in order and fall
-- back to a plain frame so a missing template can never break the page.
local function Make(kind, name, parent, ...)
    for i = 1, select("#", ...) do
        local template = select(i, ...)
        if template then
            local ok, f = pcall(CreateFrame, kind, name, parent, template)
            if ok and f then return f end
        end
    end
    return CreateFrame(kind, name, parent)
end

local function MakeCheckbox(parent, refs, id, label, x, y, get, set, tipText)
    local cb = Make("CheckButton", "EagleEye20Check" .. id, parent,
        "UICheckButtonTemplate", "InterfaceOptionsCheckButtonTemplate", "SettingsCheckboxTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    -- Blizzard templates may ship handlers that expect an internal setting
    -- object; ours drive the state directly, so drop any inherited handlers.
    cb:SetScript("OnEnter", nil)
    cb:SetScript("OnLeave", nil)
    cb:SetScript("OnClick", nil)

    local text = cb.Text or _G[cb:GetName() and (cb:GetName() .. "Text") or ""]
    if not text then
        text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb.Text = text
    end
    text:SetText(label)
    text:SetTextColor(0.9, 0.9, 0.9)
    cb:SetHitRectInsets(0, -150, 0, 0)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
    end)
    if tipText then
        cb:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tipText, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:HookScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    table.insert(refs, function()
        if ns.db then
            cb:SetChecked(get() and true or false)
        end
    end)
    return cb
end

local function MakeSlider(parent, refs, id, label, x, y, minv, maxv, step, fmt, get, set, width)
    local name = "EagleEye20Slider" .. id
    local s = Make("Slider", name, parent,
        "OptionsSliderTemplate", "UISliderTemplate", "MinimalSliderTemplate")
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 18)
    s:SetWidth(width or 175)

    if name and _G[name .. "Text"] then
        _G[name .. "Text"]:Hide()
    end
    local low = name and _G[name .. "Low"]
    local high = name and _G[name .. "High"]
    if low then low:SetText("") end
    if high then high:SetText("") end

    local labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    labelText:SetWidth((width or 175) + 30)
    labelText:SetJustifyH("LEFT")
    labelText:SetTextColor(0.9, 0.9, 0.9)

    local updating = false

    local function paint(v)
        labelText:SetText(fmt(v))
    end

    s:SetScript("OnValueChanged", function(_, value)
        if updating then return end
        local v = math.floor(value / step + 0.5) * step
        paint(v)
        set(v)
    end)

    table.insert(refs, function()
        if not ns.db then return end
        updating = true
        s:SetMinMaxValues(minv, maxv)
        if s.SetValueStep then s:SetValueStep(step) end
        if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
        s:SetValue(get())
        updating = false
        paint(get())
    end)

    return s
end

local function MakeDropdown(parent, refs, id, label, x, y, width, items, get, set)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(label)
    lbl:SetTextColor(0.9, 0.9, 0.9)

    local dd = Make("Frame", "EagleEye20Drop" .. id, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", parent, "TOPLEFT", x - 16, y - 14)
    UIDropDownMenu_SetWidth(dd, width)

    local function GetItemList()
        local list = {}
        local found = false
        local current = get and get()
        for _, item in ipairs(items) do
            table.insert(list, item)
            if item.value == current then
                found = true
            end
        end
        if not found and current and current ~= "" then
            local shortName = tostring(current):match("([^\\/]+)%.%w+$") or tostring(current):match("([^\\/]+)$") or tostring(current)
            table.insert(list, { text = "Custom (" .. shortName .. ")", value = current })
        end
        return list
    end

    local function GetLabelForValue(val)
        local list = GetItemList()
        for _, item in ipairs(list) do
            if item.value == val then
                return item.text
            end
        end
        return tostring(val or "")
    end

    UIDropDownMenu_Initialize(dd, function()
        local current = get()
        local list = GetItemList()
        for _, item in ipairs(list) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.value = item.value
            info.checked = (current == item.value)
            info.func = function()
                set(item.value)
                UIDropDownMenu_SetSelectedValue(dd, item.value)
                UIDropDownMenu_SetText(dd, item.text)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    table.insert(refs, function()
        if ns.db then
            local value = get()
            UIDropDownMenu_SetSelectedValue(dd, value)
            UIDropDownMenu_SetText(dd, GetLabelForValue(value))
        end
    end)

    return dd
end

local function MakeEditbox(parent, refs, id, label, x, y, width, get, set)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(label)
    lbl:SetTextColor(0.85, 0.85, 0.88)

    local eb = Make("EditBox", "EagleEye20Edit" .. id, parent, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 16)
    eb:SetWidth(width)
    eb:SetHeight(20)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        set(self:GetText() or "")
    end)
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    table.insert(refs, function()
        if ns.db and not eb:HasFocus() then
            eb:SetText(get() or "")
        end
    end)

    return eb
end

local function MakePanelButton(parent, label, x, y, width, onClick)
    local b = Make("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(width)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function RefreshPanel(panel)
    if not ns.db or not panel._refreshers then return end
    for _, fn in ipairs(panel._refreshers) do
        fn()
    end
end

local function SetProfileValue(key, after)
    return function(v)
        if not ns.db then return end
        ns.db.profile[key] = v
        if after then after(v) end
        ns.Fire("SettingsChanged")
    end
end

local function SetCustomValue(key)
    return function(v)
        if not ns.db then return end
        ns.db.profile[key] = v
        ns.db.profile.preset = "CUSTOM"
        ns.ApplyPreset()
        ns.Fire("TimersChanged")
        ns.Fire("ConfigRefresh")
    end
end

local function HookPanelLifecycle(panel)
    panel:SetScript("OnShow", function()
        RefreshPanel(panel)
    end)
    ns.On("ConfigRefresh", function()
        if panel:IsShown() then RefreshPanel(panel) end
    end)
    panel.okay = function() end
    panel.cancel = function()
        RefreshPanel(panel)
    end
    panel.default = function()
        RefreshPanel(panel)
    end
end

-- Wraps a page's controls in a scroll frame so the page still fits when the
-- Settings canvas is smaller than the content, with full mouse wheel scrolling.
local function ScrollablePanel(panel, height)
    local scrollName = (panel:GetName() or "EagleEye20Panel") .. "Scroll"
    local scroll = CreateFrame("ScrollFrame", scrollName, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)

    local scrollBar = _G[scrollName .. "ScrollBar"]
    scroll.ScrollBar = scrollBar

    local function OnScrollWheel(self, delta)
        local sb = scroll.ScrollBar
        if sb then
            local minVal, maxVal = sb:GetMinMaxValues()
            if maxVal and maxVal > (minVal or 0) then
                local current = sb:GetValue() or 0
                local step = 36
                if delta > 0 then
                    sb:SetValue(math.max(minVal, current - step))
                else
                    sb:SetValue(math.min(maxVal, current + step))
                end
                return
            end
        end

        local current = scroll:GetVerticalScroll() or 0
        local maxRange = scroll:GetVerticalScrollRange() or 0
        local step = 36
        if delta > 0 then
            scroll:SetVerticalScroll(math.max(0, current - step))
        else
            scroll:SetVerticalScroll(math.min(maxRange, current + step))
        end
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", OnScrollWheel)

    local content = CreateFrame("Frame", scrollName .. "Content", scroll)
    content:SetSize(580, height)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        if width and width > 0 then content:SetWidth(width) end
    end)

    content:EnableMouseWheel(true)
    content:SetScript("OnMouseWheel", function(_, delta)
        OnScrollWheel(scroll, delta)
    end)

    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        OnScrollWheel(scroll, delta)
    end)

    panel.ScrollFrame = scroll
    return content
end

-- Creates a settings page. On 3.3.5a the page is registered with the legacy
-- InterfaceOptions frame, which reparents and shows it when selected; until
-- then it must stay hidden so its clickable children do not float over the
-- native UI.
local function CreatePage(name, title)
    local panel = CreateFrame("Frame", name, UIParent)
    panel.name = title
    panel._refreshers = {}
    panel:Hide()
    return panel, panel._refreshers
end

local function RegisterPanel(panel, parentCategory)
    -- 3.3.5a: legacy InterfaceOptions API. Subcategories are expressed with
    -- the panel.parent string, never with a Settings-style category object.
    if InterfaceOptions_AddCategory then
        if parentCategory then
            -- The engine matches frame.parent against each category's name,
            -- so pass the parent's name string, not the parent frame object.
            panel.parent = (type(parentCategory) == "table" and parentCategory.name) and parentCategory.name or tostring(parentCategory)
        end
        InterfaceOptions_AddCategory(panel)
        return panel
    end
    return panel
end

local function CreateMainPanel()
    local panel, refs = CreatePage("EagleEye20MainOptions", "Eagle Eye 20/20/20")

    local page = ScrollablePanel(panel, 820)

    -- Header: 48x48 Addon Icon with Title and Subtitle (Logo kept off options)
    local icon = page:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.MEDIA .. "Icon")
    icon:SetWidth(48)
    icon:SetHeight(48)
    icon:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -10)

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -4)
    title:SetText("Eagle Eye 20/20/20")

    local subtitle = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Combat-aware eye strain timer. 20 min work, 20 sec rest, 20 ft away.")
    subtitle:SetTextColor(0.7, 0.7, 0.74)

    -- Symmetrical 3-Column Coordinates
    local col1_x = 16
    local col2_x = 210
    local col3_x = 404
    local COL_W = 175
    local DROP_W = 155

    local function MakeSectionHeader(titleText, y)
        local h = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", page, "TOPLEFT", col1_x, y)
        h:SetText(titleText)
        h:SetTextColor(0.0, 0.85, 0.65)

        local line = page:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -3)
        line:SetSize(568, 1)
        SetSolidColor(line, 0.25, 0.25, 0.30, 0.6)
        return h
    end

    -- =========================================================================
    -- GROUP 1: AUTOMATION & SAFETY
    -- =========================================================================
    MakeSectionHeader("AUTOMATION & SAFETY", -76)

    MakeCheckbox(page, refs, "Enabled", "Enable timer", col1_x, -102,
        function() return Profile().enabled end,
        function(v) ns.SetEnabled(v) end,
        "Turns the whole eye strain timer on or off.")

    MakeCheckbox(page, refs, "AFK", "Auto-reset after 60s AFK", col2_x, -102,
        function() return Profile().autoResetOnAFK end,
        SetProfileValue("autoResetOnAFK"),
        "Resets the work timer if you have been flagged AFK for a minute or more.")

    MakeCheckbox(page, refs, "Taxi", "Prompt on flight paths", col3_x, -102,
        function() return Profile().promptOnTaxi end,
        SetProfileValue("promptOnTaxi"),
        "Offers a Take Break Now button when flying with under 5 minutes left.")

    MakeCheckbox(page, refs, "Inn", "Auto-start in sanctuary/inn", col1_x, -134,
        function() return Profile().autoStartInInn end,
        SetProfileValue("autoStartInInn"),
        "Starts the eye break blackout automatically when due inside an inn or rested city.")

    MakeCheckbox(page, refs, "HoldDeath", "Hold break while dead", col2_x, -134,
        function() return Profile().holdOnDeath ~= false end,
        SetProfileValue("holdOnDeath"),
        "Displays DEAD / GHOST - WAITING and suppresses break prompts while dead or corpse-running.")

    MakeCheckbox(page, refs, "HoldVehicle", "Hold break in vehicle", col3_x, -134,
        function() return Profile().holdOnVehicle ~= false end,
        SetProfileValue("holdOnVehicle"),
        "Displays IN VEHICLE - WAITING and holds break prompts while in a vehicle.")

    MakeDropdown(page, refs, "Abort", "When break cancelled", col1_x, -168, DROP_W,
        ABORT_ITEMS,
        function() return Profile().abortAction end,
        SetProfileValue("abortAction"))

    -- =========================================================================
    -- GROUP 2: TIMER PRESETS & DURATIONS
    -- =========================================================================
    MakeSectionHeader("TIMER PRESETS & DURATIONS", -226)

    MakeDropdown(page, refs, "Preset", "Timer preset (work / distance / rest)", col1_x, -254, DROP_W,
        PRESET_ITEMS,
        function() return Profile().preset end,
        function(v)
            ns.SetPreset(v)
            RefreshPanel(panel)
        end)

    MakeSlider(page, refs, "CustomWork", "Custom work duration", col2_x, -254, 1, 120, 1,
        function(v) return string.format("Work duration: %d min", v) end,
        function() return Profile().customWorkMinutes end,
        SetCustomValue("customWorkMinutes"), COL_W)

    MakeSlider(page, refs, "CustomRest", "Custom rest duration", col3_x, -254, 5, 120, 5,
        function(v) return string.format("Rest duration: %d sec", v) end,
        function() return Profile().customRestSeconds end,
        SetCustomValue("customRestSeconds"), COL_W)

    MakeSlider(page, refs, "CustomDistance", "Custom distance", col1_x, -312, 1, 100, 1,
        function(v) return string.format("Distance: %d ft", v) end,
        function() return Profile().customDistanceFeet end,
        SetCustomValue("customDistanceFeet"), COL_W)

    MakeSlider(page, refs, "Warning", "Warning lead time", col2_x, -312, 10, 300, 5,
        function(v) return string.format("Warning lead: %d sec", v) end,
        function() return Profile().warningDuration end,
        SetProfileValue("warningDuration"), COL_W)

    MakeSlider(page, refs, "Snooze", "Snooze step", col3_x, -312, 15, 300, 15,
        function(v) return string.format("Snooze step: %d sec", v) end,
        function() return Profile().snoozeDuration end,
        SetProfileValue("snoozeDuration"), COL_W)

    -- =========================================================================
    -- GROUP 3: DISPLAY & APPEARANCE (Widget & Minimap)
    -- =========================================================================
    MakeSectionHeader("DISPLAY & APPEARANCE", -374)

    MakeCheckbox(page, refs, "ShowWidget", "Show floating widget", col1_x, -402,
        function() return Profile().showWidget ~= false end,
        function(v)
            if not ns.db then return end
            ns.db.profile.showWidget = v and true or false
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
            ns.Fire("SettingsChanged")
        end,
        "Displays the compact draggable floating countdown timer frame on your screen.")

    MakeCheckbox(page, refs, "Locked", "Lock widget position", col2_x, -402,
        function() return Profile().locked end,
        SetProfileValue("locked"),
        "Prevents dragging the floating countdown timer frame with the mouse.")

    MakeCheckbox(page, refs, "Minimap", "Show minimap button", col3_x, -402,
        function() return Profile().showMinimap end,
        function(v)
            if not ns.db then return end
            ns.db.profile.showMinimap = v and true or false
            if ns.ApplyMinimapSettings then ns.ApplyMinimapSettings() end
            ns.Fire("SettingsChanged")
        end,
        "Adds the Eagle Eye icon next to your minimap.")

    MakeSlider(page, refs, "Scale", "Widget scale", col1_x, -438, 0.6, 1.5, 0.05,
        function(v) return string.format("Widget scale: %.2fx", v) end,
        function() return Profile().widgetScale end,
        SetProfileValue("widgetScale", function()
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
        end), COL_W)

    local function GetBreakOpacity()
        local p = Profile()
        if p.overlayStyle == "VIGNETTE" then
            return p.softDimAlpha or 0.70
        else
            return p.blackoutAlpha or 0.95
        end
    end

    local function SetBreakOpacity(v)
        local p = Profile()
        if p.overlayStyle == "VIGNETTE" then
            p.softDimAlpha = v
        else
            p.blackoutAlpha = v
        end
        ns.Fire("SettingsChanged")
    end

    local function FormatBreakOpacity(v)
        local p = Profile()
        local label = (p.overlayStyle == "VIGNETTE") and "Vignette opacity" or "Blackout opacity"
        return string.format("%s: %d%%", label, math.floor(v * 100 + 0.5))
    end

    MakeDropdown(page, refs, "OverlayStyle", "Break visual style", col2_x, -438, DROP_W,
        OVERLAY_STYLE_ITEMS,
        function() return Profile().overlayStyle or "SOLID" end,
        function(v)
            if not ns.db then return end
            ns.db.profile.overlayStyle = v
            ns.Fire("SettingsChanged")
            RefreshPanel(panel)
        end)

    MakeSlider(page, refs, "BreakOpacity", "Break screen opacity", col3_x, -438, 0.40, 1.00, 0.05,
        FormatBreakOpacity,
        GetBreakOpacity,
        SetBreakOpacity,
        COL_W)

    MakeDropdown(page, refs, "FontFace", "Countdown font", col1_x, -496, DROP_W,
        FONT_ITEMS,
        function() return Profile().fontFace end,
        function(v)
            if v == "" then v = "Fonts\\FRIZQT__.TTF" end
            ns.db.profile.fontFace = v
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
            ns.Fire("SettingsChanged")
        end)

    MakeSlider(page, refs, "FontSize", "Countdown font size", col2_x, -496, 10, 24, 1,
        function(v) return string.format("Countdown font size: %d", v) end,
        function() return Profile().fontSize end,
        SetProfileValue("fontSize", function()
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
        end), COL_W)

    MakeDropdown(page, refs, "Outline", "Countdown outline", col3_x, -496, DROP_W,
        OUTLINE_ITEMS,
        function()
            local v = Profile().fontOutline
            return (v == nil or v == "") and "NONE" or v
        end,
        function(v)
            ns.db.profile.fontOutline = (v == "NONE") and "" or v
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
            ns.Fire("SettingsChanged")
        end)

    MakeDropdown(page, refs, "MinimapShape", "Minimap shape", col1_x, -554, DROP_W,
        MINIMAP_SHAPE_ITEMS,
        function() return Profile().minimapShape or "AUTO" end,
        function(v)
            if not ns.db then return end
            ns.db.profile.minimapShape = v
            if ns.ApplyMinimapSettings then ns.ApplyMinimapSettings() end
            ns.Fire("SettingsChanged")
        end)

    -- =========================================================================
    -- GROUP 4: ACTIONS & KEYBINDINGS
    -- =========================================================================
    MakeSectionHeader("ACTIONS & KEYBINDINGS", -620)

    MakePanelButton(page, "Test Break", col1_x, -646, COL_W, function()
        ns.TestBreak()
    end)

    MakePanelButton(page, "Show / Center Widget", col2_x, -646, COL_W, function()
        if not ns.db then return end
        local p = ns.db.profile
        p.widgetPoint = "CENTER"
        p.widgetRelPoint = "CENTER"
        p.widgetX = 0
        p.widgetY = 0
        p.widgetScale = 1
        p.showWidget = true
        p.enabled = true
        if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
        local w = ns.Widget or _G["EagleEye20Widget"]
        if w then
            w:ClearAllPoints()
            w:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            w:SetScale(1)
            w:SetFrameStrata("HIGH")
            w:SetFrameLevel(100)
            w:Show()
            w:Raise()
        end
        ns.Fire("SettingsChanged")
        ns.Fire("ConfigRefresh")
        ns.Print("Floating widget centered and shown.")
    end)

    -- Interactive Keybind Button with Overwrite Verification
    local keybindBtn
    local function GetSafeKeyText()
        local k1, k2 = GetBindingKey("EAGLEEYE20_CONFIRMSAFE")
        if k1 and k1 ~= "" then
            return "Safe Key: [" .. k1 .. "]"
        end
        return "Safe Key: [None]"
    end

    local function ApplySafeKey(k)
        local old1, old2 = GetBindingKey("EAGLEEYE20_CONFIRMSAFE")
        if old1 then SetBinding(old1, nil) end
        if old2 then SetBinding(old2, nil) end
        SetBinding(k, "EAGLEEYE20_CONFIRMSAFE")
        if SaveBindings and GetCurrentBindingSet then
            SaveBindings(GetCurrentBindingSet())
        end
        if keybindBtn then keybindBtn:SetText(GetSafeKeyText()) end
        ns.Print("Safe Now bound to [" .. k .. "]")
    end

    local bindingListener = CreateFrame("Frame", nil, page)
    bindingListener:Hide()

    keybindBtn = MakePanelButton(page, GetSafeKeyText(), col3_x, -646, COL_W, function()
        if bindingListener:IsShown() then
            bindingListener:Hide()
            keybindBtn:SetText(GetSafeKeyText())
            return
        end
        keybindBtn:SetText("Press key (ESC cancels)...")
        bindingListener:Show()
    end)

    bindingListener:SetScript("OnKeyDown", function(self, key)
        self:Hide()
        if key == "ESCAPE" then
            keybindBtn:SetText(GetSafeKeyText())
            return
        end
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
            return
        end

        local modifier = ""
        if IsShiftKeyDown() then modifier = "SHIFT-" .. modifier end
        if IsControlKeyDown() then modifier = "CTRL-" .. modifier end
        if IsAltKeyDown() then modifier = "ALT-" .. modifier end
        local fullKey = modifier .. key

        local existingAction = GetBindingAction(fullKey)
        if existingAction and existingAction ~= "" and existingAction ~= "EAGLEEYE20_CONFIRMSAFE" then
            local actionName = _G["BINDING_NAME_" .. existingAction] or existingAction
            local dialog = StaticPopup_Show("EAGLEEYE20_CONFIRM_OVERWRITE", fullKey, actionName)
            if dialog then
                dialog.applyFunc = function()
                    ApplySafeKey(fullKey)
                end
                dialog.cancelFunc = function()
                    keybindBtn:SetText(GetSafeKeyText())
                    ns.Print("Keybinding change cancelled.")
                end
            else
                ApplySafeKey(fullKey)
            end
        else
            ApplySafeKey(fullKey)
        end
    end)
    table.insert(refs, function()
        keybindBtn:SetText(GetSafeKeyText())
    end)

    MakePanelButton(page, "Open Event Log", col1_x, -678, COL_W, function()
        if ns.ToggleLog then ns.ToggleLog() end
    end)

    MakePanelButton(page, "Reset Minimap", col2_x, -678, COL_W, function()
        if not ns.db then return end
        ns.db.profile.minimapAngle = 250
        if ns.ApplyMinimapSettings then ns.ApplyMinimapSettings() end
        ns.Fire("SettingsChanged")
        ns.Fire("ConfigRefresh")
        ns.Print("Minimap button reset to default angle.")
    end)

    local statsLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local function UpdateStats()
        local s = ns.db and ns.db.stats or {}
        statsLabel:SetText(string.format("Lifetime Stats:  Completed: %d  |  Snoozed: %d  |  Interrupted: %d  |  Cancelled: %d",
            s.completed or 0, s.snoozed or 0, s.combatInterrupted or 0, s.manualAborted or 0))
    end

    MakePanelButton(page, "Reset Stats", col3_x, -678, COL_W, function()
        if not ns.db then return end
        ns.db.stats = { completed = 0, snoozed = 0, combatInterrupted = 0, manualAborted = 0 }
        ns.session = { completed = 0, snoozed = 0, combatInterrupted = 0, manualAborted = 0 }
        ns.Log("STATS_RESET", "Statistics cleared")
        ns.Fire("StatsChanged")
        UpdateStats()
        ns.Print("Statistics reset: all completed, snoozed, and interrupted counters set to 0.")
    end)

    -- =========================================================================
    -- GROUP 5: LIFETIME STATISTICS
    -- =========================================================================
    MakeSectionHeader("LIFETIME STATISTICS", -722)
    statsLabel:SetPoint("TOPLEFT", page, "TOPLEFT", col1_x, -748)
    statsLabel:SetTextColor(0.0, 0.85, 0.65)
    table.insert(refs, UpdateStats)

    local verText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    verText:SetPoint("TOPLEFT", page, "TOPLEFT", col1_x, -776)
    verText:SetText(string.format("Eagle Eye 20/20/20 |cff00cc99v%s|r  |  WotLK 3.3.5a (Interface 30000)", ns.version or "0.20.0-alpha-wotlk"))
    verText:SetTextColor(0.55, 0.60, 0.65)

    local fixedFooter = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fixedFooter:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 6)
    fixedFooter:SetText(string.format("EagleEye20 v%s", ns.version or "0.20.0-alpha-wotlk"))

    HookPanelLifecycle(panel)
    ns.ConfigPanel = panel
    return RegisterPanel(panel)
end

local function CreateAudioPanel(parentCategory)
    local panel, refs = CreatePage("EagleEye20AudioOptions", "Audio & Announcements")

    local page = ScrollablePanel(panel, 500)

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -10)
    title:SetText("Audio & Announcements")

    local subtitle = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Sound alert dropdowns and chat announcement configuration.")
    subtitle:SetTextColor(0.7, 0.7, 0.74)

    -- Column 1: Audio Alerts (x = 16)
    MakeCheckbox(page, refs, "Sounds", "Enable sound alerts", 16, -56,
        function() return Profile().soundEnabled end,
        SetProfileValue("soundEnabled"))

    local soundRows = {
        { id = "SoundWarning", label = "Warning sound", key = "soundWarning" },
        { id = "SoundReady", label = "Ready alert sound", key = "soundReady" },
        { id = "SoundStart", label = "Break start sound", key = "soundBreakStart" },
        { id = "SoundEnd", label = "Break complete sound", key = "soundBreakEnd" },
        { id = "SoundCombat", label = "Combat cancel sound", key = "soundCombatCancel" },
    }

    for i, row in ipairs(soundRows) do
        local y = -90 - (i - 1) * 46
        MakeDropdown(page, refs, row.id, row.label, 16, y, 190, SOUND_ITEMS,
            function() return Profile()[row.key] end,
            function(v)
                ns.db.profile[row.key] = v
                ns.Fire("SettingsChanged")
            end)

        local play = Make("Button", nil, page, "UIPanelButtonTemplate")
        play:SetWidth(46)
        play:SetHeight(22)
        play:SetPoint("TOPLEFT", page, "TOPLEFT", 220, y - 14)
        play:SetText("Play")
        play:SetScript("OnClick", function()
            local path = Profile()[row.key]
            if path and path ~= "" then
                ns.PlaySoundFile(path, true)
            end
        end)
    end

    MakeDropdown(page, refs, "SoundReadyRepeat", "Repeat ready chime while waiting", 16, -326, 190, READY_REPEAT_ITEMS,
        function() return (Profile().soundReadyRepeat ~= nil) and Profile().soundReadyRepeat or 30 end,
        SetProfileValue("soundReadyRepeat"))

    -- Column 2: Announcements (x = 300)
    MakeCheckbox(page, refs, "AnnounceParty", "Announce breaks to party", 300, -56,
        function() return Profile().announceParty end,
        SetProfileValue("announceParty"),
        "Sends the start/end message to PARTY chat.")

    MakeCheckbox(page, refs, "AnnounceSolo", "Also display messages in chat when solo", 300, -84,
        function() return Profile().announceSolo ~= false end,
        SetProfileValue("announceSolo"),
        "Prints the start and end messages to your local chat window when playing solo.")

    MakeCheckbox(page, refs, "AnnounceRaid", "Also announce in raids", 300, -112,
        function() return Profile().announceRaid end,
        SetProfileValue("announceRaid"),
        "Without this, no party/raid announcement is sent while in a raid group.")

    MakeCheckbox(page, refs, "AnnounceEnd", "Announce when the break ends", 300, -140,
        function() return Profile().announceEnd end,
        SetProfileValue("announceEnd"),
        "Sends the return message when the rest timer finishes.")

    MakeEditbox(page, refs, "StartMsg", "Break start message ({distance} and {rest} tokens)", 300, -184, 260,
        function() return Profile().partyStartMsg end,
        function(v) ns.db.profile.partyStartMsg = v end)

    MakeEditbox(page, refs, "EndMsg", "Break end message ({rest} token)", 300, -238, 260,
        function() return Profile().partyEndMsg end,
        function(v) ns.db.profile.partyEndMsg = v end)

    local fixedFooter = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fixedFooter:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 6)
    fixedFooter:SetText(string.format("EagleEye20 v%s", ns.version or "0.20.0-alpha-wotlk"))

    HookPanelLifecycle(panel)
    return RegisterPanel(panel, parentCategory)
end

function ns.OpenConfig()
    -- 3.3.5a: open the legacy Interface Options frame on our category.
    -- Calling OpenToCategory twice works around the known 3.3.5 quirk where
    -- the first call only selects the category without displaying the frame.
    if InterfaceOptionsFrame_OpenToCategory then
        pcall(InterfaceOptionsFrame_OpenToCategory, "Eagle Eye 20/20/20")
        pcall(InterfaceOptionsFrame_OpenToCategory, "Eagle Eye 20/20/20")
        return
    end
end

ns.RegisterInit(function()
    local mainCategory = CreateMainPanel()
    CreateAudioPanel(mainCategory)
    ns.ConfigCategory = mainCategory
end)
