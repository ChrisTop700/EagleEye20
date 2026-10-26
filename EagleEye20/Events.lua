local AddonName, ns = ...

local frame = CreateFrame("Frame", "EagleEye20Events", UIParent)

local wasAfk = false
local afkSince = nil
local afkPaused = false
local afkResetDone = false
local taxiPrompted = false

local function Announce(msg, requireEndFlag)
    if not ns.db then return end
    local p = ns.db.profile
    if requireEndFlag and not p.announceEnd then return end

    local text = ns.FormatMessage(msg)
    if not text or text == "" then return end

    if ns.InRaid() then
        if p.announceRaid then
            SendChatMessage(text, "RAID")
        end
    elseif ns.InGroup() then
        if p.announceParty then
            SendChatMessage(text, "PARTY")
        end
    else
        -- Solo: print message to player's chat frame if enabled
        if p.announceSolo ~= false then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00cc99" .. text .. "|r")
        end
    end
end

function ns.AnnounceBreakStart()
    Announce(ns.db.profile.partyStartMsg, false)
end

function ns.AnnounceBreakEnd()
    Announce(ns.db.profile.partyEndMsg, true)
end

local function HandleAFKStart()
    if not ns.db then return end
    wasAfk = true
    afkSince = GetTime()
    afkResetDone = false
    if (ns.state == ns.RUNNING or ns.state == ns.PREPARE) and ns.db.profile.enabled then
        ns.resumeState = ns.state
        ns.SetState(ns.PAUSED)
        afkPaused = true
        ns.Log("AUTO_PAUSE_AFK", "AFK detected - timer paused")
    end
    ns.Fire("AFKStart")
end

local function HandleAFKEnd()
    if not ns.db then return end
    wasAfk = false
    afkSince = nil
    if afkPaused then
        afkPaused = false
        if ns.state == ns.PAUSED then
            ns.ResumeTimer()
        end
    end
    afkResetDone = false
    ns.Fire("AFKEnd")
end

local function SyncAFK()
    local afk = ns.IsAFK()
    if afk and not wasAfk then
        HandleAFKStart()
    elseif not afk and wasAfk then
        HandleAFKEnd()
    end
end

local function CheckTaxi()
    if not ns.db then return end
    local p = ns.db.profile
    local onTaxi = UnitOnTaxi and UnitOnTaxi("player")
    if onTaxi and p.promptOnTaxi and p.enabled then
        if not taxiPrompted and ns.state == ns.RUNNING and ns.timeRemaining < 300 then
            taxiPrompted = true
            ns.Log("TAXI_PROMPT", "Flight path boarded with under 5 minutes remaining")
            ns.Fire("TaxiPrompt")
        end
    elseif taxiPrompted then
        taxiPrompted = false
        ns.Fire("TaxiEnd")
    end
end

ns.SafeRegister(frame, "PLAYER_REGEN_DISABLED")
ns.SafeRegister(frame, "PLAYER_REGEN_ENABLED")
ns.SafeRegister(frame, "PLAYER_ENTERING_WORLD")
-- PLAYER_FLAGS_CHANGED is not delivered by every client build; a one second
-- poll covers AFK state there without needing the event at all.
ns.SafeRegister(frame, "PLAYER_FLAGS_CHANGED")
ns.SafeRegister(frame, "PLAYER_LOGIN")

-- Tier 1 Safety Gates: Death / Ghost, Vehicle, Cinematic
ns.SafeRegister(frame, "PLAYER_DEAD")
ns.SafeRegister(frame, "PLAYER_ALIVE")
ns.SafeRegister(frame, "PLAYER_UNGHOST")
ns.SafeRegister(frame, "UNIT_ENTERED_VEHICLE")
ns.SafeRegister(frame, "UNIT_EXITED_VEHICLE")
ns.SafeRegister(frame, "CINEMATIC_START")
ns.SafeRegister(frame, "CINEMATIC_STOP")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_REGEN_DISABLED" then
        ns.Fire("CombatStart")
        if ns.state == ns.RESTING then
            ns.InterruptRestByCombat()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.Fire("CombatEnd")
        if ns.state == ns.READY_WAITING then
            ns.Fire("StateChanged", ns.state, ns.state)
        end
    elseif event == "PLAYER_DEAD" then
        ns.Fire("DeathStart")
        if ns.state == ns.RESTING then
            ns.InterruptRestByDeath()
        end
        ns.Fire("StateChanged", ns.state, ns.state)
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        ns.Fire("DeathEnd")
        ns.Fire("StateChanged", ns.state, ns.state)
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if arg1 == "player" or arg1 == nil then
            ns.Fire("VehicleChanged")
            ns.Fire("StateChanged", ns.state, ns.state)
        end
    elseif event == "CINEMATIC_START" then
        if ns.state == ns.RESTING then
            ns.InterruptRestByCinematic()
        end
        ns.Fire("CinematicStart")
        ns.Fire("StateChanged", ns.state, ns.state)
    elseif event == "CINEMATIC_STOP" then
        ns.Fire("CinematicStop")
        ns.Fire("StateChanged", ns.state, ns.state)
    elseif event == "PLAYER_FLAGS_CHANGED" then
        if arg1 == "player" or arg1 == nil then
            SyncAFK()
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        SyncAFK()
        CheckTaxi()
    end
end)

local accum = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    accum = accum + elapsed
    if accum < 1 then return end
    accum = 0
    if not ns.db then return end

    SyncAFK()

    if wasAfk and afkSince and not afkResetDone then
        local p = ns.db.profile
        if p.autoResetOnAFK and (GetTime() - afkSince) >= 60 then
            afkResetDone = true
            if ns.state == ns.PAUSED or ns.state == ns.RUNNING or ns.state == ns.PREPARE then
                ns.timeRemaining = p.workDuration
                ns.Log("AUTO_RESET_AFK", "AFK for 60s or more - work timer reset")
                ns.Fire("TimersChanged")
            end
        end
    end

    if taxiPrompted or (UnitOnTaxi and UnitOnTaxi("player") and ns.state == ns.RUNNING) then
        CheckTaxi()
    end
end)
