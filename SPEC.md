# Project Specification: Eagle Eye 20/20/20 (`EagleEye20`)

## 1. Project Overview & Target Environment
- **Official Display Title:** `Eagle Eye 20/20/20`
- **Technical Addon / Folder Name:** `EagleEye20`
- **SavedVariables Identifier:** `EagleEye20DB`
- **Target Client:** World of Warcraft 3.3.5a (Wrath of the Lich King / WoW Forever)
- **Interface Version:** `30300`
- **Language:** Lua 5.1 / WoW XML
- **Core Purpose:** Implements the 20-20-20 eye strain prevention rule (every 20 minutes of screen time, look 20 feet away for 20 seconds) tailored for an active multiplayer MMO environment where players must confirm they are in a safe state before their screen blacks out.
- **Timer Presets:** Ships with `20/20/20` (default), `30/30/20`, `45/45/20`, `60/60/20` and a `CUSTOM` scheme where the player enters their own work-minutes / look-away-feet / rest-seconds.

---

## 2. CRITICAL 3.3.5a API Constraints (Strict Agent Instructions)
When generating code for this project, adhere strictly to the **WoW 3.3.5a (Interface 30300)** environment:
1. **NO `C_Timer`:** Do not use `C_Timer.After` or `C_Timer.NewTicker`. Implement all timers using a dedicated frame's `OnUpdate` script with an `elapsed` throttle accumulator (e.g., updating every `0.1` seconds).
2. **NO `BackdropTemplate`:** Do not inherit `"BackdropTemplate"` in `CreateFrame()`. In 3.3.5a, `SetBackdrop()` and `SetBackdropColor()` are native methods on standard `Frame` objects.
3. **Group Detection:** Do not use `IsInGroup()` or `IsInRaid()` (Retail/MoP+). Use `GetNumPartyMembers() > 0` and `GetNumRaidMembers() > 0`.
4. **Audio Playback:** Use `PlaySoundFile("path\\to\\file.mp3")` or `PlaySound("SoundKitName")` (string-based, not numeric SoundKit IDs).
5. **Animations:** Use `UIFrameFadeIn(frame, timeToFade, startAlpha, endAlpha)` and `UIFrameFadeOut(...)` or manual alpha interpolation via `OnUpdate`.
6. **Zero External Dependencies:** Build using pure native 3.3.5a Lua APIs (no Ace3 or LibStub required).

---

## 3. Repository & File Architecture
The addon must reside in a folder named `EagleEye20` and follow a modular, single-namespace table pattern (`local AddonName, ns = ...`):

    EagleEye20/
    ├── EagleEye20.toc          # Title: Eagle Eye 20/20/20, Interface: 30300, SavedVariables: EagleEye20DB
    ├── Core.lua                # Namespace init, SavedVariables defaults, state machine, slash commands
    ├── Events.lua              # WoW API event hooks (Combat, AFK, Taxi, Group status, Resting)
    ├── UI_Widget.lua           # Draggable mini-timer frame, controls (Start/Pause/Confirm/Snooze)
    ├── UI_Blackout.lua         # Fullscreen overlay, 20s countdown, emergency cancel handlers
    ├── UI_Log.lua              # Scrollable event history & session compliance statistics window
    └── UI_Config.lua           # Settings GUI integrated into InterfaceOptionsFrame_OpenToCategory

### `.toc` File Header Specification (`EagleEye20.toc`)

    ## Interface: 30300
    ## Title: Eagle Eye |cff00cc9920/20/20|r
    ## Notes: Smart 20-20-20 eye strain timer with combat safety checks for WoW Forever.
    ## Author: Chris
    ## Version: 1.0.0
    ## SavedVariables: EagleEye20DB

    Core.lua
    Events.lua
    UI_Widget.lua
    UI_Blackout.lua
    UI_Log.lua
    UI_Config.lua

---

## 4. State Machine Specification
The core timer engine in `Core.lua` must operate as a strict 5-state finite state machine:

### State 1: `RUNNING`
- Counts down from `workDuration` (default: `1200` seconds / 20 minutes).
- Mini-widget displays `MM:SS` remaining and a green/teal progress bar.
- Transitions to `PREPARE` when `timeRemaining <= warningDuration` (→ 1 minute left).

### State 2: `PREPARE` (19-Minute Warning)
- Triggers once when crossing the warning threshold (default: 1 minute remaining).
- Plays configurable Warning Sound.
- Visual indicator shifts to Amber; displays an early `"Safe Now"` action button allowing the player to start the break immediately if they are between combat pulls.
- Transitions to `READY_WAITING` when `timeRemaining <= 0`.

### State 3: `READY_WAITING` (Safety Gate)
- Timer reaches `00:00` and holds.
- Plays configurable Ready Alert Sound (with optional repeat interval).
- Visual indicator shifts to Coral Red and pulses gently.
- **Safety Check:** If `UnitAffectingCombat("player")` is `true`, widget displays `"IN COMBAT - WAITING"` and suppresses the confirmation prompt until `PLAYER_REGEN_ENABLED` fires.
- Once out of combat, prompts the user with a `"Start 20s Break"` button (and optional snooze button: `+1m` / `+2m`).
- Transitions to `RESTING` only upon explicit user confirmation (button click, keybind, or slash command), OR automatically if `autoStartInInn` is enabled and `IsResting()` is `true`.

### State 4: `RESTING` (20-Second Blackout)
- Triggered when player confirms safety.
- **Party Notification:** If `announceParty` is enabled and `GetNumPartyMembers() > 0` (and `GetNumRaidMembers() == 0` unless `announceRaid` is toggled), sends configured message to `"PARTY"` chat channel.
- Plays configurable Break Start Sound.
- Fades in the fullscreen Blackout Frame over `0.5` seconds.
- Counts down from `restDuration` (default: `20` seconds).
- **Emergency Overrides:**
  - If `PLAYER_REGEN_DISABLED` (player enters combat) fires during `RESTING`, immediately hide the Blackout Frame, play Combat Alert Sound, log event as `INTERRUPTED_COMBAT`, and transition back to `READY_WAITING`.
  - If player double-clicks the Blackout Frame or presses `ESCAPE`, abort break, log event as `ABORTED_MANUAL`, and transition to `PAUSED` or reset based on user config.
- When `restTimer <= 0`:
  - Plays configurable Break Complete Sound (critical so the user knows to look back at the screen without peeking early).
  - Optionally sends `"Back!"` message to party if enabled.
  - Logs event as `COMPLETED`.
  - Fades out Blackout Frame and transitions to `RUNNING` with a fresh `1200`s timer.

### State 5: `PAUSED`
- Freezes current `timeRemaining`.
- Can be toggled manually via the Mini-Widget Play/Pause button or automatically when the player goes `<AFK>` (`UnitIsAFK("player")`).

---

## 5. UI & Visual Requirements (Modern Flat Aesthetic)

### 5.1 Design Language
- **No Default Blizzard Tooltips/Borders:** Use flat, modern styling via `bgFile = "Interface\\Buttons\\WHITE8X8"` and `edgeFile = "Interface\\Buttons\\WHITE8X8"` with `edgeSize = 1`.
- **Color Palette:**
  - Background: Dark Charcoal (`0.08, 0.08, 0.10, 0.88`)
  - Border: Subtle Slate (`0.25, 0.25, 0.30, 1.0`)
  - State Colors: Teal (`0.0, 0.8, 0.6`), Amber (`0.95, 0.65, 0.1`), Coral Red (`0.9, 0.25, 0.25`)

### 5.2 Draggable Mini-Widget (`UI_Widget.lua`)
- Compact rectangular frame (default `140x42`, scalable via settings).
- Subtle header or tooltip displaying `Eagle Eye 20/20/20`.
- Movable (`SetMovable(true)`, `RegisterForDrag("LeftButton")`), clamped to screen (`SetClampedToScreen(true)`), with option to lock position. Saves coordinates (`point, relativePoint, xOfs, yOfs`) in `EagleEye20DB`.
- **Elements:**
  - Countdown Text (`MM:SS`) with configurable Font Face, Font Size, and Outline.
  - Interactive icon/text buttons: **Play/Pause**, **Reset**, and a contextual **Confirm Safe / Snooze** button that appears during `PREPARE` and `READY_WAITING`.
  - 2px bottom status bar reflecting progress and current state color.

### 5.3 Fullscreen Blackout Overlay (`UI_Blackout.lua`)
- Frame Strata: `FULLSCREEN_DIALOG`, covering `UIParent` (`SetAllPoints(UIParent)`).
- Opacity configurable (default `0.95` dark background).
- Centered title: `"EAGLE EYE 20/20/20"`
- Centered instructional sub-header: `"LOOK {distance} FEET AWAY"` where `{distance}` comes from the active preset.
- Large centered countdown timer (`20` down to `0`).
- Subtle bottom hint text: `"Double-click anywhere or press ESC to emergency cancel (Auto-cancels on combat)"`.

### 5.4 Event Log & Stats Window (`UI_Log.lua`)
- Toggled via `/ee20 log` or a small icon on the Mini-Widget.
- Displays current session & lifetime stats:
  - Total Breaks Completed
  - Breaks Snoozed / Delayed
  - Combat Interruptions
  - Compliance Rate (%)
- Scrollable list of timestamped events (max 100 entries stored in `SavedVariables` FIFO queue):
  - Format: `[HH:MM:SS] Event Type - Details` (e.g., `[14:20:05] BREAK_COMPLETED - 20s rest finished`).

---

## 6. Smart MMO Context Features & Slash Commands

### 6.1 Core Context Features
1. **AFK Auto-Reset:** Hook `PLAYER_FLAGS_CHANGED`. If `UnitIsAFK("player")` remains true for >= 60 seconds, automatically reset the work timer to `20:00` and log `AUTO_RESET_AFK`.
2. **Flight Path Prompt:** Hook `PLAYER_CONTROL_LOST` / check `UnitOnTaxi("player")`. If the player boards a flight path with less than 5 minutes remaining on the work timer, display the `"Take Break Now"` prompt on the widget.
3. **Resting / Inn Behavior:** Use `IsResting()` to allow an optional configuration setting (`autoStartInInn`) or auto-pause while standing inside a capital city or inn.
4. **Tradeskill / Crafting Sync (Optional):** Hook `UNIT_SPELLCAST_START` to detect long batch crafting casts and offer a one-click break button.
5. **Timer Presets:** The scheme is selectable from `20/20/20` (default), `30/30/20`, `45/45/20`, `60/60/20`, or `CUSTOM`. The three numbers read as work-minutes / look-away-feet / rest-seconds. Selecting a preset writes `workDuration`, `restDuration` and `distanceFeet`; `CUSTOM` exposes controls for each of those values. The blackout instruction (`LOOK X FEET AWAY`) and party messages substitute `{distance}` and `{rest}` tokens with the active values. Changing the scheme while the work timer is running restarts it at the new work duration.

### 6.2 Slash Commands & Aliases
Register all three slash command aliases in `Core.lua`:

    SLASH_EAGLEEYE201 = "/ee20"
    SLASH_EAGLEEYE202 = "/eagleeye20"
    SLASH_EAGLEEYE203 = "/202020"
    SlashCmdList["EAGLEEYE20"] = function(msg) ... end

**Supported Subcommands (works with any of the 3 aliases):**
- `/ee20` (empty) — Opens Config UI (`Eagle Eye 20/20/20` options panel)
- `/ee20 start` / `/ee20 pause` / `/ee20 reset` — Timer controls
- `/ee20 safe` or `/ee20 confirm` — Confirms safety and starts the 20s blackout (when in `PREPARE` or `READY_WAITING`)
- `/ee20 snooze` — Adds 60 seconds to current timer
- `/ee20 preset` — Prints the active preset; `/ee20 preset 30` (or `30/30/20`, `custom`) switches scheme
- `/ee20 log` — Toggles the Event Log window
- `/ee20 test` — Triggers an immediate transition to `PREPARE` (with 5s left) to test warnings, party chat, and blackout flow.

---

## 7. SavedVariables Schema (`EagleEye20DB`)
Initialize `EagleEye20DB` on `ADDON_LOADED` with the following default schema:

    local defaults = {
        profile = {
            enabled = true,
            locked = false,
            workDuration = 1200,        -- 20 minutes in seconds
            warningDuration = 60,       -- 1 minute pre-warning
            restDuration = 20,          -- 20 seconds break
            snoozeDuration = 60,        -- 1 minute snooze
            preset = "20/20/20",        -- "20/20/20", "30/30/20", "45/45/20", "60/60/20", "CUSTOM"
            customWorkMinutes = 20,     -- applied when preset == "CUSTOM"
            customRestSeconds = 20,
            customDistanceFeet = 20,
            distanceFeet = 20,          -- effective look-away distance (display only)
            abortAction = "PAUSE",      -- manual abort of a break: "PAUSE" or "RESET"
            blackoutAlpha = 0.95,
            autoResetOnAFK = true,
            promptOnTaxi = true,
            autoStartInInn = false,
            
            -- Widget Appearance
            widgetPoint = "CENTER",
            widgetRelPoint = "CENTER",
            widgetX = 0,
            widgetY = 200,
            widgetScale = 1.0,
            fontFace = "Fonts\\FRIZQT__.TTF",
            fontSize = 16,
            fontOutline = "OUTLINE",
            
            -- Audio Settings
            soundEnabled = true,
            soundWarning = "Sound\\Interface\\RaidWarning.wav",
            soundReady = "Sound\\Interface\\ReadyCheck.wav",
            soundBreakStart = "Sound\\Interface\\MapPing.wav",
            soundBreakEnd = "Sound\\Interface\\LevelUp.wav",
            soundCombatCancel = "Sound\\Interface\\Error.wav",
            
            -- Party Chat Settings
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
        logs = {} -- Array of max 100 entries: { timestamp = "YYYY-MM-DD HH:MM:SS", event = "STRING", detail = "STRING" }
    }

---

## 8. Implementation Milestones for the AI Agent
Please build the addon sequentially in the following order, providing complete, drop-in ready files for each step:
1. **Step 1:** `EagleEye20.toc` and `Core.lua` (SavedVariables initialization, logging utility, state machine engine, `OnUpdate` ticker, and `/ee20`, `/eagleeye20`, `/202020` slash command router including `/ee20 test`).
2. **Step 2:** `Events.lua` (Combat detection `PLAYER_REGEN_DISABLED`/`ENABLED`, AFK detection, Taxi detection, and safe Party Chat dispatcher).
3. **Step 3:** `UI_Widget.lua` and `UI_Blackout.lua` (Modern flat-styled draggable timer widget and fullscreen blackout frame with emergency escape handlers).
4. **Step 4:** `UI_Log.lua` and `UI_Config.lua` (Scrollable log/stats viewer and in-game settings panel with the timer-preset selector plus custom timers, registered under `"Eagle Eye 20/20/20"`).
