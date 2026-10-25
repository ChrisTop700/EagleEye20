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

local function MakeSlider(parent, refs, id, label, x, y, minv, maxv, step, fmt, get, set)
    local name = "EagleEye20Slider" .. id
    local s = Make("Slider", name, parent,
        "OptionsSliderTemplate", "UISliderTemplate", "MinimalSliderTemplate")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetWidth(150)

    local labelText = (name and _G[name .. "Text"]) or s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if not labelText:GetPoint() then
        labelText:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 2)
    end
    labelText:SetWidth(185)
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

    local labelByValue = {}
    for _, item in ipairs(items) do
        labelByValue[item.value] = item.text
    end

    UIDropDownMenu_Initialize(dd, function()
        local current = get()
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.value = item.value
            info.checked = (current == item.value)
            info.func = function()
                set(item.value)
                UIDropDownMenu_SetSelectedValue(dd, item.value)
                UIDropDownMenu_SetText(dd, labelByValue[item.value] or tostring(item.value))
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    table.insert(refs, function()
        if ns.db then
            local value = get()
            UIDropDownMenu_SetSelectedValue(dd, value)
            UIDropDownMenu_SetText(dd, labelByValue[value] or tostring(value))
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

    local page = ScrollablePanel(panel, 420)

    local emblem = page:CreateTexture(nil, "ARTWORK")
    emblem:SetTexture(ns.MEDIA .. "Icon")
    emblem:SetWidth(32)
    emblem:SetHeight(32)
    emblem:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -4)

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 44, -12)
    title:SetText("Eagle Eye 20/20/20")

    local subtitle = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("Combat-aware eye break timer. Pick a preset or define your own scheme.")
    subtitle:SetTextColor(0.7, 0.7, 0.74)

    local logo = page:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ns.MEDIA .. "Logo")
    logo:SetWidth(96)
    logo:SetHeight(96)
    logo:SetPoint("TOPRIGHT", page, "TOPRIGHT", -24, -14)
    logo:SetAlpha(0.85)

    MakeCheckbox(page, refs, "Enabled", "Enable timer", 16, -52,
        function() return Profile().enabled end,
        function(v) ns.SetEnabled(v) end,
        "Turns the whole addon on or off.")

    MakeDropdown(page, refs, "Preset", "Timer preset (work / distance / rest)", 16, -84, 160,
        PRESET_ITEMS,
        function() return Profile().preset end,
        function(v) ns.SetPreset(v) end)

    MakeSlider(page, refs, "CustomWork", "Custom work duration", 16, -140, 1, 120, 1,
        function(v) return string.format("Custom work duration: %d min", v) end,
        function() return Profile().customWorkMinutes end,
        SetCustomValue("customWorkMinutes"))

    MakeSlider(page, refs, "CustomRest", "Custom rest duration", 16, -184, 5, 120, 5,
        function(v) return string.format("Custom rest duration: %d sec", v) end,
        function() return Profile().customRestSeconds end,
        SetCustomValue("customRestSeconds"))

    MakeSlider(page, refs, "CustomDistance", "Custom look-away distance", 16, -228, 1, 100, 1,
        function(v) return string.format("Custom look-away distance: %d ft", v) end,
        function() return Profile().customDistanceFeet end,
        SetCustomValue("customDistanceFeet"))

    MakeSlider(page, refs, "Snooze", "Snooze step", 16, -272, 15, 300, 15,
        function(v) return string.format("Snooze step: %d sec", v) end,
        function() return Profile().snoozeDuration end,
        SetProfileValue("snoozeDuration"))

    MakeDropdown(page, refs, "Abort", "When a break is cancelled manually", 16, -316, 160,
        ABORT_ITEMS,
        function() return Profile().abortAction end,
        SetProfileValue("abortAction"))

    MakeCheckbox(page, refs, "Locked", "Lock widget position", 212, -52,
        function() return Profile().locked end,
        SetProfileValue("locked"),
        "Prevents dragging the mini widget with the mouse.")

    MakeCheckbox(page, refs, "AFK", "Auto-reset after 60s AFK", 212, -78,
        function() return Profile().autoResetOnAFK end,
        SetProfileValue("autoResetOnAFK"),
        "Resets the work timer if the player has been flagged AFK for a minute or more.")

    MakeCheckbox(page, refs, "Taxi", "Prompt on flight paths", 212, -104,
        function() return Profile().promptOnTaxi end,
        SetProfileValue("promptOnTaxi"),
        "Shows a Take Break Now button when flying with under 5 minutes left.")

    MakeCheckbox(page, refs, "Inn", "Auto-start while resting", 212, -130,
        function() return Profile().autoStartInInn end,
        SetProfileValue("autoStartInInn"),
        "Starts the blackout automatically when the break is due inside an inn or city.")

    MakeSlider(page, refs, "Warning", "Warning lead time", 212, -166, 10, 300, 5,
        function(v) return string.format("Warning lead time: %d sec", v) end,
        function() return Profile().warningDuration end,
        SetProfileValue("warningDuration"))

    MakeSlider(page, refs, "Scale", "Widget scale", 212, -210, 0.6, 1.5, 0.05,
        function(v) return string.format("Widget scale: %.2fx", v) end,
        function() return Profile().widgetScale end,
        SetProfileValue("widgetScale", function()
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
        end))

    MakeSlider(page, refs, "FontSize", "Countdown font size", 212, -254, 10, 22, 1,
        function(v) return string.format("Countdown font size: %d", v) end,
        function() return Profile().fontSize end,
        SetProfileValue("fontSize", function()
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
        end))

    MakeDropdown(page, refs, "Outline", "Countdown outline", 212, -298, 150,
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

    MakeEditbox(page, refs, "FontFace", "Countdown font path", 404, -52, 170,
        function() return Profile().fontFace end,
        function(v)
            if v == "" then v = "Fonts\\FRIZQT__.TTF" end
            ns.db.profile.fontFace = v
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
            ns.Fire("SettingsChanged")
        end)

    MakePanelButton(page, "Test Break", 404, -100, 120, function()
        ns.TestBreak()
    end)

    MakePanelButton(page, "Open Log", 404, -128, 120, function()
        if ns.ToggleLog then ns.ToggleLog() end
    end)

    MakePanelButton(page, "Reset Stats", 404, -156, 120, function()
        if not ns.db then return end
        ns.db.stats = { completed = 0, snoozed = 0, combatInterrupted = 0, manualAborted = 0 }
        ns.session = { completed = 0, snoozed = 0, combatInterrupted = 0, manualAborted = 0 }
        ns.Log("STATS_RESET", "Statistics cleared")
        ns.Fire("StatsChanged")
    end)

    MakePanelButton(page, "Reset Position", 404, -184, 120, function()
        if not ns.db then return end
        local p = ns.db.profile
        p.widgetPoint = "CENTER"
        p.widgetRelPoint = "CENTER"
        p.widgetX = 0
        p.widgetY = 200
        p.widgetScale = 1
        if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
        ns.Fire("SettingsChanged")
        ns.Fire("ConfigRefresh")
    end)

    MakeCheckbox(page, refs, "Minimap", "Show minimap button", 404, -216,
        function() return Profile().showMinimap end,
        function(v)
            if not ns.db then return end
            ns.db.profile.showMinimap = v and true or false
            if ns.ApplyMinimapSettings then ns.ApplyMinimapSettings() end
            ns.Fire("SettingsChanged")
        end,
        "Adds the Eagle Eye icon next to the minimap. Left-click opens this panel, right-click pauses or resumes.")

    MakePanelButton(page, "Reset Minimap", 404, -244, 120, function()
        if not ns.db then return end
        ns.db.profile.minimapAngle = 250
        if ns.ApplyMinimapSettings then ns.ApplyMinimapSettings() end
        ns.Fire("SettingsChanged")
        ns.Fire("ConfigRefresh")
    end)

    HookPanelLifecycle(panel)
    ns.ConfigPanel = panel
    return RegisterPanel(panel)
end

local function CreateAudioPanel(parentCategory)
    local panel, refs = CreatePage("EagleEye20AudioOptions", "Audio & Announcements")

    local page = ScrollablePanel(panel, 420)

    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -12)
    title:SetText("Audio & Announcements")

    local subtitle = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Sound cues and what gets announced to your group.")
    subtitle:SetTextColor(0.7, 0.7, 0.74)

    MakeCheckbox(page, refs, "Sounds", "Enable sound alerts", 16, -52,
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
        local y = -82 - (i - 1) * 34
        local eb = MakeEditbox(page, refs, row.id, row.label, 16, y, 250,
            function() return Profile()[row.key] end,
            function(v) ns.db.profile[row.key] = v end)

        local play = Make("Button", nil, page, "UIPanelButtonTemplate")
        play:SetWidth(48)
        play:SetHeight(20)
        play:SetPoint("TOPLEFT", page, "TOPLEFT", 276, y - 16)
        play:SetText("Play")
        play:SetScript("OnClick", function()
            local path = eb:GetText()
            if path and path ~= "" then
                if ns.PlaySoundFile then
                    ns.PlaySoundFile(path)
                elseif PlaySoundFile then
                    PlaySoundFile(path, "Master")
                end
            end
        end)
    end

    MakeCheckbox(page, refs, "AnnounceParty", "Announce breaks to party", 16, -256,
        function() return Profile().announceParty end,
        SetProfileValue("announceParty"),
        "Sends the start/end message to PARTY chat.")

    MakeCheckbox(page, refs, "AnnounceRaid", "Also announce in raids", 16, -282,
        function() return Profile().announceRaid end,
        SetProfileValue("announceRaid"),
        "Without this, no announcement is sent while in a raid group.")

    MakeCheckbox(page, refs, "AnnounceEnd", "Announce when the break ends", 16, -308,
        function() return Profile().announceEnd end,
        SetProfileValue("announceEnd"))

    MakeEditbox(page, refs, "StartMsg", "Break start message ({distance} and {rest} tokens)", 16, -342, 380,
        function() return Profile().partyStartMsg end,
        function(v) ns.db.profile.partyStartMsg = v end)

    MakeEditbox(page, refs, "EndMsg", "Break end message ({rest} token)", 16, -382, 380,
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
