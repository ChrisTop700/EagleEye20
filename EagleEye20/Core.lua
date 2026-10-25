local AddonName, ns = ...

_G[AddonName] = ns

BINDING_HEADER_EAGLEEYE20 = "Eagle Eye 20/20/20"
BINDING_NAME_EAGLEEYE20_CONFIRMSAFE = "Confirm Safe / Start Break"
BINDING_NAME_EAGLEEYE20_SNOOZE = "Snooze Pending Break"
BINDING_NAME_EAGLEEYE20_PAUSERESUME = "Pause / Resume Timer"

ns.name = AddonName
ns.version = "0.10.0"
ns.MEDIA = "Interface\\AddOns\\EagleEye20\\Textures\\"

-- The client is a modern (Forever, interface 16001) build. Frames only get
-- SetBackdrop when they are created with the BackdropTemplate mixin, the old
-- InterfaceOptions panel container is gone, and group/AFK helpers changed.
function ns.Backdrop()
    return BackdropTemplateMixin and "BackdropTemplate" or nil
end

function ns.NewFrame(kind, name, parent)
    local f = CreateFrame(kind, name, parent, ns.Backdrop())
    -- Clients without the backdrop mixin have no SetBackdrop at all; shim the
    -- methods so shared code can call them unconditionally.
    if not f.SetBackdrop then
        f.SetBackdrop = function() end
        f.SetBackdropColor = function() end
        f.SetBackdropBorderColor = function() end
    end
    return f
end

function ns.SafeRegister(frame, event)
    if not event then return false end
    return (pcall(frame.RegisterEvent, frame, event))
end

function ns.InRaid()
    if IsInRaid then return IsInRaid() and true or false end
    if GetNumRaidMembers then return GetNumRaidMembers() > 0 end
    return false
end

function ns.InGroup()
    if IsInGroup then return IsInGroup() and true or false end
    if GetNumPartyMembers then return GetNumPartyMembers() > 0 end
    return false
end

function ns.IsAFK()
    if UnitIsAFK then return UnitIsAFK("player") and true or false end
    if UnitIsDND then return UnitIsDND("player") and true or false end
    return false
end

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if math.atan then return math.atan(y, x) end
    return 0
end
ns.Atan2 = Atan2

function ns.RotatePoint(cx, cy, x, y)
    return math.deg(Atan2(y - cy, x - cx)) % 360
end

ns.RUNNING = "RUNNING"
ns.PREPARE = "PREPARE"
ns.READY_WAITING = "READY_WAITING"
ns.RESTING = "RESTING"
ns.PAUSED = "PAUSED"

ns.COLORS = {
    [ns.RUNNING] = { r = 0.00, g = 0.80, b = 0.60 },
    [ns.PREPARE] = { r = 0.95, g = 0.65, b = 0.10 },
    [ns.READY_WAITING] = { r = 0.90, g = 0.25, b = 0.25 },
    [ns.RESTING] = { r = 0.00, g = 0.80, b = 0.60 },
    [ns.PAUSED] = { r = 0.55, g = 0.55, b = 0.60 },
}

ns.PRESETS = {
    ["20/20/20"] = { work = 1200, rest = 20, distance = 20 },
    ["30/30/20"] = { work = 1800, rest = 20, distance = 30 },
    ["45/45/20"] = { work = 2700, rest = 20, distance = 45 },
    ["60/60/20"] = { work = 3600, rest = 20, distance = 60 },
}

ns.PRESET_ORDER = { "20/20/20", "30/30/20", "45/45/20", "60/60/20", "CUSTOM" }

ns.PRESET_ALIASES = {
    ["20"] = "20/20/20",
    ["20/20/20"] = "20/20/20",
    ["30"] = "30/30/20",
    ["30/30/20"] = "30/30/20",
    ["45"] = "45/45/20",
    ["45/45/20"] = "45/45/20",
    ["60"] = "60/60/20",
    ["60/60/20"] = "60/60/20",
    ["custom"] = "CUSTOM",
    ["c"] = "CUSTOM",
}

ns.state = nil
ns.timeRemaining = 0
ns.restTimer = 0
ns.resumeState = nil
ns.db = nil

ns.session = {
    completed = 0,
    snoozed = 0,
    combatInterrupted = 0,
    manualAborted = 0,
}

local defaults = {
    profile = {
        enabled = true,
        locked = false,
        workDuration = 1200,
        warningDuration = 60,
        restDuration = 20,
        snoozeDuration = 60,
        preset = "20/20/20",
        customWorkMinutes = 20,
        customRestSeconds = 20,
        customDistanceFeet = 20,
        distanceFeet = 20,
        abortAction = "PAUSE",
        blackoutAlpha = 0.95,
        autoResetOnAFK = true,
        promptOnTaxi = true,
        autoStartInInn = false,

        widgetPoint = "CENTER",
        widgetRelPoint = "CENTER",
        widgetX = 0,
        widgetY = 260,
        widgetScale = 1.0,
        showWidget = true,
        showMinimap = true,
        minimapAngle = 250,
        fontFace = "Fonts\\FRIZQT__.TTF",
        fontSize = 16,
        fontOutline = "OUTLINE",

        soundEnabled = true,
        soundWarning = "Sound\\Interface\\RaidWarning.wav",
        soundReady = "Sound\\Interface\\ReadyCheck.wav",
        soundBreakStart = "Sound\\Interface\\MapPing.wav",
        soundBreakEnd = "Sound\\Interface\\LevelUp.wav",
        soundCombatCancel = "Sound\\Interface\\Error.wav",

        announceParty = true,
        announceRaid = false,
        announceEnd = false,
        partyStartMsg = "[EagleEye20] Casting Eagle Eye {distance} feet away ({rest}s eye break)!",
        partyEndMsg = "[EagleEye20] Back from {rest}s eye break!",
    },
    stats = {
        completed = 0,
        snoozed = 0,
        combatInterrupted = 0,
        manualAborted = 0,
    },
    logs = {},
}

local listeners = {}

function ns.On(event, fn)
    if not listeners[event] then
        listeners[event] = {}
    end
    table.insert(listeners[event], fn)
end

function ns.Fire(event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff3333EagleEye20:|r " .. tostring(err))
        end
    end
end

local initQueue = {}
local dbReady = false

function ns.RegisterInit(fn)
    if dbReady then
        fn()
    else
        table.insert(initQueue, fn)
    end
end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00cc99[EagleEye20]|r " .. tostring(msg))
end

local function fillDefaults(tbl, src)
    for k, v in pairs(src) do
        if tbl[k] == nil then
            tbl[k] = v
        end
    end
end

function ns.ApplyPreset(silent)
    if not ns.db then return end
    local p = ns.db.profile
    local key = p.preset or "20/20/20"
    if key == "CUSTOM" then
        p.customWorkMinutes = math.max(1, math.min(120, math.floor(tonumber(p.customWorkMinutes) or 20)))
        p.customRestSeconds = math.max(5, math.min(120, math.floor(tonumber(p.customRestSeconds) or 20)))
        p.customDistanceFeet = math.max(1, math.min(100, math.floor(tonumber(p.customDistanceFeet) or 20)))
        p.workDuration = p.customWorkMinutes * 60
        p.restDuration = p.customRestSeconds
        p.distanceFeet = p.customDistanceFeet
    else
        local pre = ns.PRESETS[key] or ns.PRESETS["20/20/20"]
        p.preset = ns.PRESETS[key] and key or "20/20/20"
        p.workDuration = pre.work
        p.restDuration = pre.rest
        p.distanceFeet = pre.distance
    end
    if not silent then
        ns.Fire("TimersChanged")
    end
end

function ns.SetPreset(key)
    if not ns.db then return end
    local p = ns.db.profile
    local preset = ns.PRESET_ALIASES[string.lower(key or "")]
    if not preset then
        ns.Print("Unknown preset. Use 20, 30, 45, 60 or custom.")
        return false
    end
    p.preset = preset
    ns.ApplyPreset()
    if ns.state == ns.RUNNING or ns.state == ns.PREPARE then
        ns.timeRemaining = p.workDuration
        if ns.state == ns.PREPARE then
            ns.SetState(ns.RUNNING)
        end
    elseif ns.state == ns.PAUSED then
        ns.timeRemaining = p.workDuration
    end
    ns.Log("PRESET_CHANGED", string.format("%s (%d min work / %ds rest / %d ft)", preset, math.floor(p.workDuration / 60 + 0.5), p.restDuration, p.distanceFeet))
    ns.Print(string.format("Preset: %s - %d min work, %ds rest, look %d ft away.", preset, math.floor(p.workDuration / 60 + 0.5), p.restDuration, p.distanceFeet))
    ns.Fire("TimersChanged")
    return true
end

function ns.FormatTime(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

function ns.FormatMessage(msg)
    if not ns.db or not msg then return "" end
    msg = tostring(msg)
    msg = string.gsub(msg, "{distance}", tostring(ns.db.profile.distanceFeet or 20))
    msg = string.gsub(msg, "{rest}", tostring(ns.db.profile.restDuration or 20))
    return msg
end

local SOUND_INFO = {
    ["Sound\\Interface\\RaidWarning.wav"] = { kit = 8959, alt = "Sound\\Interface\\RaidWarning.ogg" },
    ["Sound\\Interface\\ReadyCheck.wav"] = { kit = 8960, alt = "Sound\\Interface\\ReadyCheck.ogg" },
    ["Sound\\Interface\\MapPing.wav"] = { kit = 3175, alt = "Sound\\Interface\\MapPing.ogg" },
    ["Sound\\Interface\\LevelUp.wav"] = { kit = 618, alt = "Sound\\Interface\\LevelUp.ogg" },
    ["Sound\\Interface\\AlarmClockWarning3.wav"] = { kit = 11773, alt = "Sound\\Interface\\AlarmClockWarning3.ogg" },
    ["Sound\\Interface\\iTellMessage.wav"] = { kit = 3081, alt = "Sound\\Interface\\iTellMessage.ogg" },
    ["Sound\\Interface\\PVPThroughQueue.wav"] = { kit = 8459, alt = "Sound\\Interface\\PVPThroughQueue.ogg" },
    ["Sound\\Interface\\AuctionWindowOpen.wav"] = { kit = 5389, alt = "Sound\\Interface\\AuctionWindowOpen.ogg" },
    ["Sound\\Interface\\Error.wav"] = { kit = 8958, alt = "Sound\\Interface\\Error.ogg" },
}

function ns.PlaySoundFile(sound, force)
    if not force and (not ns.db or not ns.db.profile.soundEnabled) then return end
    if not sound or sound == "" or sound == "None" then return end

    local num = tonumber(sound)
    if num and PlaySound then
        local ok = pcall(PlaySound, num, "Master")
        if ok then return end
        pcall(PlaySound, num)
        return
    end

    local info = SOUND_INFO[sound]
    if info and info.kit and PlaySound then
        local ok = pcall(PlaySound, info.kit, "Master")
        if ok then return end
        pcall(PlaySound, info.kit)
    end

    if SOUNDKIT and type(sound) == "string" and SOUNDKIT[sound] and PlaySound then
        local ok = pcall(PlaySound, SOUNDKIT[sound], "Master")
        if ok then return end
        pcall(PlaySound, SOUNDKIT[sound])
    end

    if PlaySoundFile then
        local ok = pcall(PlaySoundFile, sound, "Master")
        if not ok then
            pcall(PlaySoundFile, sound)
        end
        if info and info.alt then
            pcall(PlaySoundFile, info.alt, "Master")
        end
    end
end

function ns.Log(event, detail)
    if not ns.db then return end
    local logs = ns.db.logs
    table.insert(logs, {
        timestamp = date("%Y-%m-%d %H:%M:%S"),
        event = tostring(event or "EVENT"),
        detail = tostring(detail or ""),
    })
    while #logs > 100 do
        table.remove(logs, 1)
    end
    ns.Fire("LogUpdated")
end

function ns.BumpStat(key)
    if not ns.db then return end
    if ns.db.stats[key] ~= nil then
        ns.db.stats[key] = ns.db.stats[key] + 1
    end
    if ns.session[key] ~= nil then
        ns.session[key] = ns.session[key] + 1
    end
    ns.Fire("StatsChanged")
end

function ns.Compliance(stats)
    stats = stats or (ns.db and ns.db.stats)
    if not stats then return 100 end
    local total = (stats.completed or 0) + (stats.snoozed or 0) + (stats.combatInterrupted or 0) + (stats.manualAborted or 0)
    if total <= 0 then return 100 end
    return math.floor(((stats.completed or 0) / total) * 100 + 0.5)
end

function ns.InCombat()
    return UnitAffectingCombat("player") and true or false
end

function ns.SetState(newState)
    local old = ns.state
    if old == newState then return end
    ns.state = newState
    ns.Fire("StateChanged", newState, old)
end

function ns.ResetTimer(silent)
    if not ns.db then return end
    if ns.state == ns.RESTING then
        ns.AbortRest("Reset during break")
    end
    ns.timeRemaining = ns.db.profile.workDuration
    if ns.state ~= ns.RUNNING then
        ns.SetState(ns.RUNNING)
    end
    if not silent then
        ns.Log("RESET", "Work timer reset to " .. ns.FormatTime(ns.timeRemaining))
    end
    ns.Fire("TimersChanged")
end

function ns.PauseTimer()
    if not ns.db then return false end
    if ns.state == ns.RUNNING or ns.state == ns.PREPARE or ns.state == ns.READY_WAITING then
        ns.resumeState = ns.state
        ns.SetState(ns.PAUSED)
        ns.Log("PAUSED", "Timer paused")
        return true
    end
    return false
end

function ns.ResumeTimer()
    if not ns.db then return false end
    if ns.state ~= ns.PAUSED then return false end
    local back = ns.resumeState
    if back ~= ns.RUNNING and back ~= ns.PREPARE and back ~= ns.READY_WAITING then
        back = ns.RUNNING
    end
    if back == ns.PREPARE and ns.timeRemaining > (ns.db.profile.warningDuration or 60) then
        back = ns.RUNNING
    end
    ns.resumeState = nil
    ns.SetState(back)
    ns.Log("RESUMED", "Timer resumed")
    return true
end

function ns.SetEnabled(on)
    if not ns.db then return end
    local p = ns.db.profile
    on = on and true or false
    if on == p.enabled then return end
    p.enabled = on
    if on then
        if ns.timeRemaining <= 0 then
            ns.timeRemaining = p.workDuration
        end
        ns.SetState(ns.RUNNING)
        ns.Log("ENABLED", "Addon enabled")
    else
        if ns.state == ns.RESTING then
            ns.AbortRest("Disabled")
        end
        ns.resumeState = nil
        ns.SetState(ns.PAUSED)
        ns.Log("DISABLED", "Addon disabled")
    end
    ns.Fire("TimersChanged")
end

function ns.Snooze(seconds)
    if not ns.db then return end
    if ns.state ~= ns.RUNNING and ns.state ~= ns.PREPARE and ns.state ~= ns.READY_WAITING then
        ns.Print("Snooze is only available while the break is pending.")
        return false
    end
    seconds = math.floor(tonumber(seconds) or ns.db.profile.snoozeDuration)
    if seconds <= 0 then seconds = ns.db.profile.snoozeDuration end
    ns.timeRemaining = math.max(0, ns.timeRemaining) + seconds
    ns.BumpStat("snoozed")
    ns.Log("SNOOZED", "+" .. seconds .. "s")
    local warning = ns.db.profile.warningDuration or 60
    if ns.timeRemaining > warning then
        ns.SetState(ns.RUNNING)
    else
        ns.SetState(ns.PREPARE)
    end
    ns.Fire("TimersChanged")
    return true
end

function ns.ConfirmSafe(force)
    if not ns.db then return false end
    if ns.state == ns.RESTING then return false end
    if ns.InCombat() then
        ns.Log("SAFE_REFUSED", "Player still in combat")
        ns.Print("You are in combat - wait until you are safe.")
        return false
    end
    if not force and ns.state ~= ns.PREPARE and ns.state ~= ns.READY_WAITING then
        ns.Print("No break is pending right now.")
        return false
    end
    local p = ns.db.profile
    ns.restTimer = p.restDuration
    ns.timeRemaining = 0
    if ns.AnnounceBreakStart then
        ns.AnnounceBreakStart()
    end
    ns.PlaySoundFile(p.soundBreakStart)
    ns.Log("BREAK_STARTED", string.format("%ds eye break started", p.restDuration))
    ns.SetState(ns.RESTING)
    ns.Fire("BreakStart")
    return true
end

function ns.CompleteRest()
    if not ns.db or ns.state ~= ns.RESTING then return end
    local p = ns.db.profile
    ns.PlaySoundFile(p.soundBreakEnd)
    if ns.AnnounceBreakEnd then
        ns.AnnounceBreakEnd()
    end
    ns.BumpStat("completed")
    ns.Log("BREAK_COMPLETED", string.format("%ds rest finished", p.restDuration))
    ns.timeRemaining = p.workDuration
    ns.restTimer = 0
    ns.SetState(ns.RUNNING)
    ns.Fire("BreakEnd")
    ns.Fire("TimersChanged")
end

function ns.InterruptRestByCombat()
    if not ns.db or ns.state ~= ns.RESTING then return end
    ns.PlaySoundFile(ns.db.profile.soundCombatCancel)
    ns.BumpStat("combatInterrupted")
    ns.Log("INTERRUPTED_COMBAT", "Combat began during rest")
    ns.timeRemaining = 0
    ns.restTimer = 0
    ns.SetState(ns.READY_WAITING)
    ns.Fire("BreakInterrupted")
end

function ns.AbortRest(reason)
    if not ns.db or ns.state ~= ns.RESTING then return end
    ns.BumpStat("manualAborted")
    ns.Log("ABORTED_MANUAL", reason or "Cancelled by player")
    ns.restTimer = 0
    if ns.db.profile.abortAction == "RESET" then
        ns.timeRemaining = ns.db.profile.workDuration
        ns.SetState(ns.RUNNING)
    else
        ns.timeRemaining = 0
        ns.resumeState = ns.READY_WAITING
        ns.SetState(ns.PAUSED)
    end
    ns.Fire("BreakAborted")
    ns.Fire("TimersChanged")
end

function ns.TestBreak()
    if not ns.db then return end
    if not ns.db.profile.enabled then
        ns.Print("Enable the addon first.")
        return
    end
    if ns.state == ns.RESTING then
        ns.Print("Finish or abort the current break first.")
        return
    end
    ns.Log("TEST", "5s test break started")
    ns.Print("Starting 5s test eye break overlay...")
    ns.restTimer = 5
    ns.timeRemaining = 0
    ns.PlaySoundFile(ns.db.profile.soundBreakStart, true)
    ns.SetState(ns.RESTING)
    ns.Fire("BreakStart")
    ns.Fire("TimersChanged")
end

function ns.Tick(dt)
    if not dbReady or not ns.db then return end
    local p = ns.db.profile

    if not p.enabled then
        ns.Fire("Tick", dt)
        return
    end

    if ns.state == ns.RUNNING then
        ns.timeRemaining = ns.timeRemaining - dt
        if ns.timeRemaining <= p.warningDuration then
            ns.timeRemaining = math.max(ns.timeRemaining, 0)
            ns.SetState(ns.PREPARE)
            ns.PlaySoundFile(p.soundWarning)
            ns.Log("WARNING", ns.FormatTime(p.warningDuration) .. " until break")
        end
    elseif ns.state == ns.PREPARE then
        ns.timeRemaining = ns.timeRemaining - dt
        if ns.timeRemaining <= 0 then
            ns.timeRemaining = 0
            ns.SetState(ns.READY_WAITING)
            ns.PlaySoundFile(p.soundReady)
            ns.Log("READY", "Break due - awaiting safety confirmation")
        end
    elseif ns.state == ns.RESTING then
        ns.restTimer = ns.restTimer - dt
        if ns.restTimer <= 0 then
            ns.restTimer = 0
            ns.CompleteRest()
        end
    elseif ns.state == ns.READY_WAITING then
        if p.autoStartInInn and IsResting() and not ns.InCombat() then
            ns.Log("AUTO_STARTED", "Resting area auto-start")
            ns.ConfirmSafe()
        end
    end

    ns.Fire("Tick", dt)
end

local ticker = CreateFrame("Frame", "EagleEye20Ticker", UIParent)
local accumulator = 0
local TICK = 0.1

ticker:SetScript("OnUpdate", function(_, elapsed)
    accumulator = accumulator + elapsed
    if accumulator < TICK then return end
    local dt = accumulator
    accumulator = 0
    ns.Tick(dt)
end)

local function InitDB()
    if type(EagleEye20DB) ~= "table" then
        EagleEye20DB = {}
    end
    if type(EagleEye20DB.profile) ~= "table" then EagleEye20DB.profile = {} end
    if type(EagleEye20DB.stats) ~= "table" then EagleEye20DB.stats = {} end
    if type(EagleEye20DB.logs) ~= "table" then EagleEye20DB.logs = {} end
    fillDefaults(EagleEye20DB.profile, defaults.profile)
    fillDefaults(EagleEye20DB.stats, defaults.stats)
    while #EagleEye20DB.logs > 100 do
        table.remove(EagleEye20DB.logs, 1)
    end

    ns.db = EagleEye20DB
    ns.ApplyPreset(true)
    dbReady = true

    ns.timeRemaining = ns.db.profile.workDuration
    ns.SetState(ns.db.profile.enabled and ns.RUNNING or ns.PAUSED)

    for i = 1, #initQueue do
        local ok, err = pcall(initQueue[i])
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff3333EagleEye20 init error:|r " .. tostring(err))
        end
    end

    ns.Log("SESSION_START", "Eagle Eye " .. ns.version .. " loaded (" .. tostring(ns.db.profile.preset) .. ")")
    ns.Fire("DBReady")
    ns.Fire("TimersChanged")
end

local boot = CreateFrame("Frame", "EagleEye20Boot")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        self:UnregisterEvent("ADDON_LOADED")
        InitDB()
    end
end)

local function PrintHelp()
    ns.Print("Commands:")
    ns.Print("  /ee20 start | pause | reset")
    ns.Print("  /ee20 safe | confirm  - start the break when safe")
    ns.Print("  /ee20 snooze [seconds]")
    ns.Print("  /ee20 preset [20|30|45|60|custom]")
    ns.Print("  /ee20 log")
    ns.Print("  /ee20 widget | show  - show or hide the floating countdown widget")
    ns.Print("  /ee20 minimap  - show or hide the minimap button")
    ns.Print("  /ee20 panic  - force-clear the break overlay if it gets stuck")
    ns.Print("  /ee20 test  - 5 second test cycle")
end

local function Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function HandlePresetCommand(arg)
    arg = Trim(arg)
    if arg == "" then
        local p = ns.db.profile
        local label = p.preset == "CUSTOM" and "CUSTOM" or tostring(p.preset)
        ns.Print(string.format("Active preset: %s - %d min work, %ds rest, look %d ft away.", label, math.floor(p.workDuration / 60 + 0.5), p.restDuration, p.distanceFeet))
        ns.Print("Options: 20/20/20, 30/30/20, 45/45/20, 60/60/20, custom")
        return
    end
    local key = (string.match(arg, "^(%S+)") or ""):lower()
    ns.SetPreset(key)
end

local function SlashHandler(msg)
    if not ns.db then
        ns.Print("Still loading, try again in a moment.")
        return
    end
    local full = Trim(msg)
    local cmd, rest = string.match(full, "^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()

    if cmd == "" then
        if ns.OpenConfig then
            ns.OpenConfig()
        end
    elseif cmd == "start" then
        if ns.ResumeTimer() then
            ns.Print("Timer resumed.")
        elseif ns.state == ns.RUNNING then
            ns.Print("Timer is already running.")
        else
            ns.ResetTimer()
            ns.Print("Timer started.")
        end
    elseif cmd == "pause" then
        if ns.PauseTimer() then
            ns.Print("Timer paused.")
        elseif ns.state == ns.PAUSED then
            ns.Print("Timer is already paused.")
        end
    elseif cmd == "reset" then
        ns.ResetTimer()
        ns.Print("Timer reset to " .. ns.FormatTime(ns.timeRemaining) .. ".")
    elseif cmd == "safe" or cmd == "confirm" then
        ns.ConfirmSafe()
    elseif cmd == "snooze" then
        if ns.Snooze(tonumber(rest)) then
            ns.Print("Snoozed. Next gate in " .. ns.FormatTime(ns.timeRemaining) .. ".")
        end
    elseif cmd == "log" then
        if ns.ToggleLog then ns.ToggleLog() end
    elseif cmd == "widget" or cmd == "show" then
        if ns.db then
            local p = ns.db.profile
            p.showWidget = not p.showWidget
            if ns.ApplyWidgetSettings then ns.ApplyWidgetSettings() end
            ns.Fire("SettingsChanged")
            ns.Fire("ConfigRefresh")
            ns.Print("Floating countdown widget " .. (p.showWidget and "shown" or "hidden") .. ".")
        end
    elseif cmd == "minimap" then
        if ns.db then
            local p = ns.db.profile
            p.showMinimap = not p.showMinimap
            if ns.ApplyMinimapSettings then ns.ApplyMinimapSettings() end
            ns.Fire("SettingsChanged")
            ns.Fire("ConfigRefresh")
            ns.Print("Minimap button " .. (p.showMinimap and "shown" or "hidden") .. ".")
        end
    elseif cmd == "test" then
        ns.TestBreak()
    elseif cmd == "panic" or cmd == "dismiss" then
        -- Recovery hatch: the break overlay covers the screen and blocks
        -- clicks by design, so provide a way to force-clear it.
        if ns.DismissBlackout then ns.DismissBlackout() end
        if ns.state == ns.RESTING then
            ns.AbortRest("Panic command")
        end
        ns.Print("Overlay cleared.")
    elseif cmd == "preset" then
        HandlePresetCommand(rest)
    elseif cmd == "help" then
        PrintHelp()
    else
        PrintHelp()
    end
end

SLASH_EAGLEEYE201 = "/ee20"
SLASH_EAGLEEYE202 = "/eagleeye20"
SLASH_EAGLEEYE203 = "/202020"
SlashCmdList["EAGLEEYE20"] = SlashHandler
