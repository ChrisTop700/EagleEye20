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
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetWidth(width or 165)

    local labelText = (name and _G[name .. "Text"]) or s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if not labelText:GetPoint() then
        labelText:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 2)
    end
    labelText:SetWidth((width or 165) + 30)
    labelText:SetJustifyH("LEFT")

    local low = name and _G[name .. "Low"]
    local high = name and _G[name .. "High"]
    if low then low:SetText("") end
    if high then high:SetText("") end

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
-- Settings canvas is smaller than the content.
local function ScrollablePanel(panel, height)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)
    -- A ScrollFrame in this template carries its own scrollbar child. Neither
    -- may take input unless the page is actually the visible settings canvas.
    scroll:EnableMouse(false)
    scroll:EnableMouseWheel(false)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(580, height)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        if width and width > 0 then content:SetWidth(width) end
    end)

    panel.ScrollFrame = scroll
    return content
end

-- Creates a settings canvas page.
--
-- The page must be explicitly hidden: the Settings API reparents and shows it
-- when the category is selected, but until then a shown page would leave its
-- clickable children (check buttons, buttons, scrollbar) floating over the
-- native UI, making menus unclickable while chat and movement still work.
local function CreatePage(name, title)
    local panel = CreateFrame("Frame", name, UIParent)
    panel.name = title
    panel._refreshers = {}
    panel:Hide()
    return panel, panel._refreshers
end

local function RegisterPanel(panel, parentCategory)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        if parentCategory then
            return Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, panel.name)
        end
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        return category
    end
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

local function CreateMainPanel()
    local panel, refs = CreatePage("EagleEye20MainOptions", "Eagle Eye 20/20/20")

    local page = ScrollablePanel(panel, 440)

    -- Header (emblem, title, subtitle on left; compact logo on right)
    local emblem = page:CreateTexture(nil, "ARTWORK")
    emblem:SetTexture(ns.MEDIA .. "Icon")
    emblem:SetWidth(32)
    emblem:SetHeight(32)
    emblem:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -8)

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", emblem, "TOPRIGHT", 10, -2)
    title:SetText("Eagle Eye 20/20/20")

    local subtitle = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Combat-aware eye break timer. Pick a preset or customize your schedule.")
    subtitle:SetTextColor(0.7, 0.7, 0.74)

    -- Sized and positioned inside header band so it never overlaps controls
    local logo = page:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ns.MEDIA .. "Logo")
    logo:SetWidth(50)
    logo:SetHeight(50)
    logo:SetPoint("TOPRIGHT", page, "TOPRIGHT", -20, -6)
    logo:SetAlpha(0.90)

    -- Symmetrical 3-Column Coordinates
    local col1_x = 16
    local col2_x = 206
    local col3_x = 396
    local COL_W = 165
    local DROP_W = 145

    -- Row 1 (y = -66): Main Status Checkboxes
    MakeCheckbox(page, refs, "Enabled", "Enable timer", col1_x, -66,
        function() return Profile().enabled end,
        function(v) ns.SetEnabled(v) end,
        "Turns the whole addon on or off.")

    MakeCheckbox(page, refs, "AFK", "Auto-reset after 60s AFK", col2_x, -66,
        function() return Profile().autoResetOnAFK end,
        SetProfileValue("autoResetOnAFK"),
        "Resets the work timer if the player has been flagged AFK for a minute or more.")

    MakeCheckbox(page, refs, "ShowWidget", "Show floating countdown widget", col3_x, -66,
        function() return Profile().showWidget ~= false end,
        function(v)
            if not ns.db then return end
            ns.db.profile.showWidget = v and true or false
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
            ns.Fire("SettingsChanged")
        end,
        "Displays the compact draggable floating countdown timer frame on your screen.")

    -- Row 2 (y = -98): Presets & Behavior
    MakeDropdown(page, refs, "Preset", "Timer preset (work / distance / rest)", col1_x, -98, DROP_W,
        PRESET_ITEMS,
        function() return Profile().preset end,
        function(v) ns.SetPreset(v) end)

    MakeCheckbox(page, refs, "Taxi", "Prompt on flight paths", col2_x, -98,
        function() return Profile().promptOnTaxi end,
        SetProfileValue("promptOnTaxi"),
        "Shows a Take Break Now button when flying with under 5 minutes left.")

    MakeCheckbox(page, refs, "Inn", "Auto-start while resting", col2_x, -124,
        function() return Profile().autoStartInInn end,
        SetProfileValue("autoStartInInn"),
        "Starts the blackout automatically when the break is due inside an inn or city.")

    MakeCheckbox(page, refs, "Locked", "Lock widget position", col3_x, -98,
        function() return Profile().locked end,
        SetProfileValue("locked"),
        "Prevents dragging the floating mini countdown widget with the mouse.")

    -- Row 3 (y = -150): Primary Sliders Row
    MakeSlider(page, refs, "CustomWork", "Custom work duration", col1_x, -150, 1, 120, 1,
        function(v) return string.format("Custom work duration: %d min", v) end,
        function() return Profile().customWorkMinutes end,
        SetCustomValue("customWorkMinutes"), COL_W)

    MakeSlider(page, refs, "Warning", "Warning lead time", col2_x, -150, 10, 300, 5,
        function(v) return string.format("Warning lead time: %d sec", v) end,
        function() return Profile().warningDuration end,
        SetProfileValue("warningDuration"), COL_W)

    MakeSlider(page, refs, "Scale", "Widget scale", col3_x, -150, 0.6, 1.5, 0.05,
        function(v) return string.format("Widget scale: %.2fx", v) end,
        function() return Profile().widgetScale end,
        SetProfileValue("widgetScale", function()
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
        end), COL_W)

    -- Row 4 (y = -196): Rest Duration / Minimap Toggle / Countdown Font Dropdown
    MakeSlider(page, refs, "CustomRest", "Custom rest duration", col1_x, -196, 5, 120, 5,
        function(v) return string.format("Custom rest duration: %d sec", v) end,
        function() return Profile().customRestSeconds end,
        SetCustomValue("customRestSeconds"), COL_W)

    MakeCheckbox(page, refs, "Minimap", "Show minimap button", col2_x, -196,
        function() return Profile().showMinimap end,
        function(v)
            if not ns.db then return end
            ns.db.profile.showMinimap = v and true or false
            if ns.ApplyMinimapSettings then ns.ApplyMinimapSettings() end
            ns.Fire("SettingsChanged")
        end,
        "Adds the Eagle Eye icon next to the minimap.")

    MakeDropdown(page, refs, "FontFace", "Countdown font", col3_x, -196, DROP_W,
        FONT_ITEMS,
        function() return Profile().fontFace end,
        function(v)
            if v == "" then v = "Fonts\\FRIZQT__.TTF" end
            ns.db.profile.fontFace = v
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
            ns.Fire("SettingsChanged")
        end)

    -- Row 5 (y = -242): Look-Away Distance / Reset Minimap / Countdown Font Size
    MakeSlider(page, refs, "CustomDistance", "Custom look-away distance", col1_x, -242, 1, 100, 1,
        function(v) return string.format("Custom look-away distance: %d ft", v) end,
        function() return Profile().customDistanceFeet end,
        SetCustomValue("customDistanceFeet"), COL_W)

    MakePanelButton(page, "Reset Minimap", col2_x, -242, COL_W, function()
        if not ns.db then return end
        ns.db.profile.minimapAngle = 250
        if ns.ApplyMinimapSettings then ns.ApplyMinimapSettings() end
        ns.Fire("SettingsChanged")
        ns.Fire("ConfigRefresh")
    end)

    MakeSlider(page, refs, "FontSize", "Countdown font size", col3_x, -242, 10, 24, 1,
        function(v) return string.format("Countdown font size: %d", v) end,
        function() return Profile().fontSize end,
        SetProfileValue("fontSize", function()
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
        end), COL_W)

    -- Row 6 (y = -288): Snooze Step / Test Break / Countdown Outline
    MakeSlider(page, refs, "Snooze", "Snooze step", col1_x, -288, 15, 300, 15,
        function(v) return string.format("Snooze step: %d sec", v) end,
        function() return Profile().snoozeDuration end,
        SetProfileValue("snoozeDuration"), COL_W)

    MakePanelButton(page, "Test Break", col2_x, -288, COL_W, function()
        ns.TestBreak()
    end)

    MakeDropdown(page, refs, "Outline", "Countdown outline", col3_x, -288, DROP_W,
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

    -- Row 7 (y = -334): Abort Action / Open Log / Reset Widget Position
    MakeDropdown(page, refs, "Abort", "When break cancelled", col1_x, -334, DROP_W,
        ABORT_ITEMS,
        function() return Profile().abortAction end,
        SetProfileValue("abortAction"))

    MakePanelButton(page, "Open Log", col2_x, -334, COL_W, function()
        if ns.ToggleLog then ns.ToggleLog() end
    end)

    MakePanelButton(page, "Reset Position", col3_x, -334, COL_W, function()
        if not ns.db then return end
        local p = ns.db.profile
        p.widgetPoint = "CENTER"
        p.widgetRelPoint = "CENTER"
        p.widgetX = 0
        p.widgetY = 200
        p.widgetScale = 1
        p.showWidget = true
        if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
        ns.Fire("SettingsChanged")
        ns.Fire("ConfigRefresh")
    end)

    -- Row 8 (y = -374): Reset Statistics
    MakePanelButton(page, "Reset Stats", col2_x, -374, COL_W, function()
        if not ns.db then return end
        ns.db.stats = { completed = 0, snoozed = 0, combatInterrupted = 0, manualAborted = 0 }
        ns.session = { completed = 0, snoozed = 0, combatInterrupted = 0, manualAborted = 0 }
        ns.Log("STATS_RESET", "Statistics cleared")
        ns.Fire("StatsChanged")
    end)

    HookPanelLifecycle(panel)
    ns.ConfigPanel = panel
    return RegisterPanel(panel)
end

local function CreateAudioPanel(parentCategory)
    local panel, refs = CreatePage("EagleEye20AudioOptions", "Audio & Announcements")

    local page = ScrollablePanel(panel, 440)

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -10)
    title:SetText("Audio & Announcements")

    local subtitle = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Sound alert dropdowns and group announcement configuration.")
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
                if ns.PlaySoundFile then
                    ns.PlaySoundFile(path)
                elseif PlaySoundFile then
                    PlaySoundFile(path, "Master")
                end
            end
        end)
    end

    -- Column 2: Announcements (x = 300)
    MakeCheckbox(page, refs, "AnnounceParty", "Announce breaks to party", 300, -56,
        function() return Profile().announceParty end,
        SetProfileValue("announceParty"),
        "Sends the start/end message to PARTY chat.")

    MakeCheckbox(page, refs, "AnnounceRaid", "Also announce in raids", 300, -84,
        function() return Profile().announceRaid end,
        SetProfileValue("announceRaid"),
        "Without this, no announcement is sent while in a raid group.")

    MakeCheckbox(page, refs, "AnnounceEnd", "Announce when the break ends", 300, -112,
        function() return Profile().announceEnd end,
        SetProfileValue("announceEnd"))

    MakeEditbox(page, refs, "StartMsg", "Break start message ({distance} and {rest} tokens)", 300, -156, 260,
        function() return Profile().partyStartMsg end,
        function(v) ns.db.profile.partyStartMsg = v end)

    MakeEditbox(page, refs, "EndMsg", "Break end message ({rest} token)", 300, -210, 260,
        function() return Profile().partyEndMsg end,
        function(v) ns.db.profile.partyEndMsg = v end)

    HookPanelLifecycle(panel)
    return RegisterPanel(panel, parentCategory)
end

ns.RegisterInit(function()
    local mainCategory = CreateMainPanel()
    CreateAudioPanel(mainCategory)
    ns.ConfigCategory = mainCategory

    ns.OpenConfig = function()
        if not mainCategory then return end
        if Settings and Settings.OpenToCategory then
            local id = mainCategory.GetID and mainCategory:GetID() or mainCategory
            Settings.OpenToCategory(id)
            -- The settings frame selects a category on show, which can land after
            -- this call; repeat once shortly after so our page stays selected.
            if C_Timer and C_Timer.After then
                C_Timer.After(0.1, function()
                    if SettingsPanel and SettingsPanel.GetCurrentCategory then
                        local current = SettingsPanel:GetCurrentCategory()
                        if current and current ~= mainCategory then
                            Settings.OpenToCategory(id)
                        end
                    end
                end)
            end
        elseif InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory("Eagle Eye 20/20/20")
        end
    end
end)
