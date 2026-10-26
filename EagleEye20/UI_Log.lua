local AddonName, ns = ...

local SetSolidColor = ns.SetSolidColor

local PANEL_WIDTH, PANEL_HEIGHT = 360, 300
local VISIBLE_ROWS = 12
local ROW_HEIGHT = 14

local f, statsText, scroll
local rows = {}
local scrollOffset = 0

local EVENT_COLORS = {
    BREAK_COMPLETED = "00cc99",
    BREAK_STARTED = "00cc99",
    READY = "ff9955",
    WARNING = "ffcc66",
    INTERRUPTED_COMBAT = "e66666",
    ABORTED_MANUAL = "ee8844",
    SNOOZED = "ffaa55",
    AUTO_RESET_AFK = "88aacc",
    AUTO_PAUSE_AFK = "88aacc",
    PRESET_CHANGED = "88ddcc",
    SESSION_START = "88aacc",
}

local DEFAULT_COLOR = "aaaaaa"

local function FormatEntry(entry)
    local clock = string.match(entry.timestamp or "", "%d%d:%d%d:%d%d$") or "--:--:--"
    local event = entry.event or "EVENT"
    local color = EVENT_COLORS[event] or DEFAULT_COLOR
    local detail = entry.detail or ""
    if detail ~= "" then
        return string.format("|cff6f7484[%s]|r |cff%s%s|r - |cff9a9aa2%s|r", clock, color, event, detail)
    end
    return string.format("|cff6f7484[%s]|r |cff%s%s|r", clock, color, event)
end

local function Refresh()
    if not f or not ns.db then return end
    local s = ns.db.stats
    local sess = ns.session

    statsText:SetText(string.format(
        "Session   completed %d   snoozed %d   combat %d   aborted %d\n" ..
        "Lifetime  completed %d   snoozed %d   combat %d   aborted %d\n" ..
        "Compliance rate: |cff00cc99%d%%|r",
        sess.completed, sess.snoozed, sess.combatInterrupted, sess.manualAborted,
        s.completed, s.snoozed, s.combatInterrupted, s.manualAborted,
        ns.Compliance(s)
    ))

    local logs = ns.db.logs
    local total = #logs
    local maxOffset = math.max(0, total - VISIBLE_ROWS)
    local offset = math.min(math.max(0, scrollOffset), maxOffset)
    scrollOffset = offset

    for i = 1, VISIBLE_ROWS do
        local index = total - (offset + i) + 1
        local row = rows[i]
        if index >= 1 then
            row:SetText(FormatEntry(logs[index]))
            row:Show()
        else
            row:SetText("")
            row:Hide()
        end
    end

    -- The rows are plain font strings and the offset is ours, so the scroll
    -- bar only needs to report movement. Range APIs differ between builds, so
    -- they are all optional.
    if scroll.SetScrollRange then
        pcall(scroll.SetScrollRange, scroll, maxOffset * ROW_HEIGHT, ROW_HEIGHT)
    end
    if scroll.SetVerticalScroll then
        pcall(scroll.SetVerticalScroll, scroll, offset * ROW_HEIGHT)
    end
end

local function CreateWindow()
    f = ns.NewFrame("Frame", "EagleEye20LogWindow", UIParent)
    f:SetWidth(PANEL_WIDTH)
    f:SetHeight(PANEL_HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.10, 0.92)
    f:SetBackdropBorderColor(0.25, 0.25, 0.30, 1.0)
    f:Hide()

    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.MEDIA .. "Icon")
    icon:SetWidth(16)
    icon:SetHeight(16)
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -8)

    local header = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 33, -10)
    header:SetText("EAGLE EYE 20/20/20  -  LOG  |cff888888v" .. (ns.version or "0.11.0-alpha") .. "|r")
    header:SetTextColor(0.0, 0.8, 0.6)

    local close = ns.NewFrame("Button", nil, f)
    close:SetWidth(20)
    close:SetHeight(20)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    close:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    close:SetBackdropColor(0.16, 0.16, 0.20, 1.0)
    close:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
    local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeText:SetPoint("CENTER")
    closeText:SetText("X")
    close:SetScript("OnClick", function()
        f:Hide()
    end)
    close:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.35, 0.18, 0.18, 1.0)
    end)
    close:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.16, 0.16, 0.20, 1.0)
    end)

    statsText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsText:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
    statsText:SetWidth(PANEL_WIDTH - 24)
    statsText:SetJustifyH("LEFT")
    statsText:SetJustifyV("TOP")
    statsText:SetTextColor(0.82, 0.82, 0.86)

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    divider:SetVertexColor(0.25, 0.25, 0.30, 1)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -92)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -92)

    for i = 1, VISIBLE_ROWS do
        local row = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -102 - (i - 1) * ROW_HEIGHT)
        row:SetWidth(PANEL_WIDTH - 44)
        row:SetJustifyH("LEFT")
        row:SetHeight(ROW_HEIGHT)
        rows[i] = row
    end

    scroll = CreateFrame("ScrollFrame", "EagleEye20LogScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -98)
    scroll:SetWidth(PANEL_WIDTH - 20)
    scroll:SetHeight(VISIBLE_ROWS * ROW_HEIGHT)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        scrollOffset = math.floor(offset / ROW_HEIGHT + 0.5)
        Refresh()
    end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local total = ns.db and #ns.db.logs or 0
        local maxOffset = math.max(0, total - VISIBLE_ROWS)
        scrollOffset = math.max(0, math.min(maxOffset, scrollOffset - delta))
        Refresh()
    end)

    local clearBtn = ns.NewFrame("Button", nil, f)
    clearBtn:SetWidth(70)
    clearBtn:SetHeight(20)
    clearBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
    clearBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    clearBtn:SetBackdropColor(0.16, 0.16, 0.20, 1.0)
    clearBtn:SetBackdropBorderColor(0.30, 0.30, 0.35, 1.0)
    local clearText = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    clearText:SetPoint("CENTER")
    clearText:SetText("Clear log")
    clearBtn:SetScript("OnClick", function()
        if not ns.db then return end
        if wipe then
            wipe(ns.db.logs)
        elseif table.wipe then
            table.wipe(ns.db.logs)
        else
            for k in pairs(ns.db.logs) do
                ns.db.logs[k] = nil
            end
        end
        ns.Log("LOGS_CLEARED", "History cleared")
        Refresh()
    end)
    clearBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.24, 0.24, 0.29, 1.0)
    end)
    clearBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.16, 0.16, 0.20, 1.0)
    end)

    local exportFrame
    local function ShowExportDialog()
        if not exportFrame then
            local ef = ns.NewFrame("Frame", "EagleEye20ExportDialog", UIParent)
            ef:SetWidth(480)
            ef:SetHeight(330)
            ef:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
            ef:SetFrameStrata("DIALOG")
            ef:SetFrameLevel(250)
            ef:SetMovable(true)
            ef:EnableMouse(true)
            ef:RegisterForDrag("LeftButton")
            ef:SetClampedToScreen(true)
            ef:SetScript("OnDragStart", ef.StartMoving)
            ef:SetScript("OnDragStop", ef.StopMovingOrSizing)
            if ef.SetBackdrop then
                pcall(ef.SetBackdrop, ef, {
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                    insets = { left = 0, right = 0, top = 0, bottom = 0 },
                })
                pcall(ef.SetBackdropColor, ef, 0.08, 0.08, 0.10, 0.96)
                pcall(ef.SetBackdropBorderColor, ef, 0.25, 0.25, 0.30, 1.0)
            end

            local bg = ef:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(ef)
            SetSolidColor(bg, 0.08, 0.08, 0.10, 0.96)
            ef.bg = bg

            -- Crisp border lines matching log window
            local function AddBorder(p1, r1, p2, r2, w, h)
                local l = ef:CreateTexture(nil, "BORDER")
                l:SetPoint(p1, ef, r1, 0, 0)
                l:SetPoint(p2, ef, r2, 0, 0)
                if w then l:SetWidth(w) end
                if h then l:SetHeight(h) end
                SetSolidColor(l, 0.25, 0.25, 0.30, 1.0)
            end
            AddBorder("TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT", nil, 1)
            AddBorder("BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT", nil, 1)
            AddBorder("TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT", 1, nil)
            AddBorder("TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT", 1, nil)

            local icon = ef:CreateTexture(nil, "ARTWORK")
            icon:SetTexture(ns.MEDIA .. "Icon")
            icon:SetWidth(16)
            icon:SetHeight(16)
            icon:SetPoint("TOPLEFT", ef, "TOPLEFT", 12, -8)

            local title = ef:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            title:SetPoint("TOPLEFT", ef, "TOPLEFT", 33, -10)
            title:SetText("EAGLE EYE 20/20/20  -  REPORT EXPORT")
            title:SetTextColor(0.0, 0.8, 0.6)

            local close = ns.NewFrame("Button", nil, ef)
            close:SetWidth(20)
            close:SetHeight(20)
            close:SetPoint("TOPRIGHT", ef, "TOPRIGHT", -6, -6)
            if close.SetBackdrop then
                pcall(close.SetBackdrop, close, {
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
                pcall(close.SetBackdropColor, close, 0.16, 0.16, 0.20, 1.0)
                pcall(close.SetBackdropBorderColor, close, 0.30, 0.30, 0.35, 1.0)
            end
            local closeBg = close:CreateTexture(nil, "BACKGROUND")
            closeBg:SetAllPoints(close)
            SetSolidColor(closeBg, 0.16, 0.16, 0.20, 1.0)
            local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            closeText:SetPoint("CENTER")
            closeText:SetText("X")
            close:SetScript("OnClick", function() ef:Hide() end)
            close:SetScript("OnEnter", function(self)
                if self.SetBackdropColor then pcall(self.SetBackdropColor, self, 0.35, 0.18, 0.18, 1.0) end
                SetSolidColor(closeBg, 0.35, 0.18, 0.18, 1.0)
            end)
            close:SetScript("OnLeave", function(self)
                if self.SetBackdropColor then pcall(self.SetBackdropColor, self, 0.16, 0.16, 0.20, 1.0) end
                SetSolidColor(closeBg, 0.16, 0.16, 0.20, 1.0)
            end)

            local note = ef:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            note:SetPoint("TOPLEFT", ef, "TOPLEFT", 12, -32)
            note:SetText("Press Ctrl+C to copy. (Future: Export format options)")
            note:SetTextColor(0.65, 0.65, 0.70)

            local inset = ns.NewFrame("Frame", nil, ef)
            inset:SetPoint("TOPLEFT", ef, "TOPLEFT", 12, -50)
            inset:SetPoint("BOTTOMRIGHT", ef, "BOTTOMRIGHT", -12, 12)
            if inset.SetBackdrop then
                pcall(inset.SetBackdrop, inset, {
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
                pcall(inset.SetBackdropColor, inset, 0.04, 0.04, 0.06, 0.95)
                pcall(inset.SetBackdropBorderColor, inset, 0.20, 0.20, 0.25, 1.0)
            end
            local inBg = inset:CreateTexture(nil, "BACKGROUND")
            inBg:SetAllPoints(inset)
            SetSolidColor(inBg, 0.04, 0.04, 0.06, 0.95)

            local sf = CreateFrame("ScrollFrame", "EagleEye20ExportScroll", inset, "UIPanelScrollFrameTemplate")
            sf:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -6)
            sf:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 6)

            local eb = CreateFrame("EditBox", "EagleEye20ExportBox", sf)
            eb:SetMultiLine(true)
            eb:SetAutoFocus(true)
            eb:SetFontObject("GameFontHighlightSmall")
            eb:SetWidth(420)
            eb:SetHeight(240)
            eb:SetScript("OnEscapePressed", function() ef:Hide() end)
            sf:SetScrollChild(eb)

            ef.editBox = eb
            exportFrame = ef
        end

        local lines = {}
        table.insert(lines, "=== Eagle Eye 20/20/20 - Report Export ===")
        table.insert(lines, "Generated: " .. date("%Y-%m-%d %H:%M:%S"))
        if ns.db and ns.db.stats then
            local s = ns.db.stats
            table.insert(lines, string.format("Completed: %d | Snoozed: %d | Combat Interrupted: %d | Cancelled: %d",
                s.completed or 0, s.snoozed or 0, s.combatInterrupted or 0, s.manualAborted or 0))
            table.insert(lines, "------------------------------------------------------------")
        end
        if ns.db and ns.db.logs then
            for i = #ns.db.logs, 1, -1 do
                local e = ns.db.logs[i]
                table.insert(lines, string.format("[%s] %-18s %s", e.timestamp or "", e.event or "", e.detail or ""))
            end
        end
        local text = table.concat(lines, "\n")
        exportFrame.editBox:SetText(text)
        exportFrame.editBox:HighlightText()
        exportFrame:Show()
        exportFrame:Raise()
    end

    local exportBtn = ns.NewFrame("Button", nil, f)
    exportBtn:SetWidth(70)
    exportBtn:SetHeight(20)
    exportBtn:SetPoint("LEFT", clearBtn, "RIGHT", 6, 0)
    if exportBtn.SetBackdrop then
        pcall(exportBtn.SetBackdrop, exportBtn, {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        pcall(exportBtn.SetBackdropColor, exportBtn, 0.16, 0.16, 0.20, 1.0)
        pcall(exportBtn.SetBackdropBorderColor, exportBtn, 0.30, 0.30, 0.35, 1.0)
    end
    local exportText = exportBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    exportText:SetPoint("CENTER")
    exportText:SetText("Export")
    exportBtn:SetScript("OnClick", ShowExportDialog)
    exportBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.24, 0.24, 0.29, 1.0)
    end)
    exportBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.16, 0.16, 0.20, 1.0)
    end)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    hint:SetText("newest first - 100 entry FIFO")
    hint:SetTextColor(0.5, 0.5, 0.55)

    f:SetScript("OnShow", Refresh)
end

function ns.ToggleLog()
    if not f then
        ns.Print("Log window not ready yet.")
        return
    end
    if f:IsShown() then
        f:Hide()
    else
        Refresh()
        f:Show()
    end
end

ns.RegisterInit(function()
    CreateWindow()
    ns.On("LogUpdated", function()
        if f:IsShown() then Refresh() end
    end)
    ns.On("StatsChanged", function()
        if f:IsShown() then Refresh() end
    end)
end)
