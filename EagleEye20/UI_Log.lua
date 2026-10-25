local AddonName, ns = ...

local PANEL_WIDTH, PANEL_HEIGHT = 360, 300
local VISIBLE_ROWS = 12
local ROW_HEIGHT = 14

local f, statsText, scroll
local rows = {}

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
    local offset = FauxScrollFrame_GetOffset(scroll)
    local total = #logs
    local maxOffset = math.max(0, total - VISIBLE_ROWS)
    if offset > maxOffset then
        offset = maxOffset
    end

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

    FauxScrollFrame_Update(scroll, total, VISIBLE_ROWS, ROW_HEIGHT)
end

local function CreateWindow()
    f = CreateFrame("Frame", "EagleEye20LogWindow", UIParent)
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

    local header = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    header:SetText("EAGLE EYE 20/20/20  -  LOG")
    header:SetTextColor(0.0, 0.8, 0.6)

    local close = CreateFrame("Button", nil, f)
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

    scroll = CreateFrame("ScrollFrame", "EagleEye20LogScroll", f, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -98)
    scroll:SetWidth(PANEL_WIDTH - 20)
    scroll:SetHeight(VISIBLE_ROWS * ROW_HEIGHT)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, Refresh)
    end)

    local clearBtn = CreateFrame("Button", nil, f)
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
        ns.db.logs = {}
        ns.Log("LOGS_CLEARED", "History cleared")
        Refresh()
    end)
    clearBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.24, 0.24, 0.29, 1.0)
    end)
    clearBtn:SetScript("OnLeave", function(self)
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
