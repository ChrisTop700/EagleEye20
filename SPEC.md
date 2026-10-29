# Project Specification: Eagle Eye 20/20/20 (`EagleEye20`)

## 1. Project Overview & Target Environment
- **Official Display Title:** `Eagle Eye 20/20/20`
- **Technical Addon / Folder Name:** `EagleEye20`
- **SavedVariables Identifier:** `EagleEye20DB`
- **Target Client:** World of Warcraft Classic Anniversary (The Burning Crusade)
- **Interface Version:** `20506`
- **Language:** Lua 5.1 / WoW XML
- **Core Purpose:** Implements the 20-20-20 eye strain prevention rule (every 20 minutes of screen time, look 20 feet away for 20 seconds) tailored for an active multiplayer MMO environment where players must confirm they are in a safe state before their screen blacks out.
- **Timer Presets:** Ships with `20/20/20` (default), `30/30/20`, `45/45/20`, `60/60/20` and a `CUSTOM` scheme where the player enters their own work-minutes / look-away-feet / rest-seconds.

---

## 2. Client API Constraints (Strict Agent Instructions)
This addon targets the **WoW Classic Anniversary client (TBC), interface `20506`**, which is a
modern API build, not vanilla 3.3.5a. Adhere to these rules:

1. **Timers:** `C_Timer.After` / `NewTicker` exist. Long-running countdowns still use an
   `OnUpdate` accumulator so they survive without spawning timers per tick.
2. **Backdrops:** `SetBackdrop` only exists on frames created with the `"BackdropTemplate"`
   template. Use `ns.NewFrame`, which passes the template when `BackdropTemplateMixin`
   is present and shims the backdrop methods when it is not.
3. **Group Detection:** Use `IsInGroup()` / `IsInRaid()`; `GetNumPartyMembers` and
   `GetNumRaidMembers` are gone. `ns.InGroup()` / `ns.InRaid()` wrap this safely.
4. **AFK Detection:** `UnitIsAFK("player")` is not reliable here and `PLAYER_FLAGS_CHANGED`
   is not always delivered; `ns.IsAFK()` plus a one second poll covers it.
5. **Options Pages:** The `InterfaceOptionsFramePanelContainer` / `InterfaceOptions_AddCategory`
   path is gone. Register pages with `Settings.RegisterCanvasLayoutCategory` +
   `Settings.RegisterAddOnCategory` (subcategories via `RegisterCanvasLayoutSubcategory`)
   and open with `Settings.OpenToCategory`.
6. **Absent Legacy Globals:** `strtrim`, `tinsert`, `FauxScrollFrame*`, `math.atan2`,
   `OptionsCheckButtonTemplate` and `OptionsSliderTemplate` do not exist. Use
   `table.insert`, a plain `ScrollFrame` + `UIPanelScrollFrameTemplate`, `ns.Atan2`, and
   template fallbacks (`UICheckButtonTemplate`, `OptionsSliderTemplate` where present).
7. **Templates Are Build-Specific:** Always create option widgets through a helper that
   tries several template names and falls back to a plain frame.
8. **Audio Playback:** `PlaySoundFile("Sound\\Interface\\...")` still works.
9. **Zero External Dependencies:** No Ace3 or LibStub required.

---

## 3. Repository & File Architecture
The addon must reside in a folder named `EagleEye20` and follow a modular, single-namespace table pattern (`local AddonName, ns = ...`):

    EagleEye20/
    â”œâ”€â”€ EagleEye20.toc          # Title: Eagle Eye 20/20/20, Interface: 20506, SavedVariables: EagleEye20DB
    â”œâ”€â”€ Core.lua                # Namespace init, SavedVariables defaults, state machine, slash commands
    â”œâ”€â”€ Events.lua              # WoW API event hooks (Combat, AFK, Taxi, Group status, Resting)
    â”œâ”€â”€ UI_Widget.lua           # Draggable mini-timer frame, controls (Start/Pause/Confirm/Snooze)
    â”œâ”€â”€ UI_Minimap.lua          # Minimap button built from the IconRound texture
    â”œâ”€â”€ UI_Blackout.lua         # Fullscreen overlay, 20s countdown, emergency cancel handlers
    â”œâ”€â”€ UI_Log.lua              # Scrollable event history & session compliance statistics window
    â”œâ”€â”€ UI_Config.lua           # Settings GUI registered through the Settings canvas category API
    â””â”€â”€ Textures/
        â”œâ”€â”€ Icon.tga            # Square addon icon (256x256), used by the .toc and small headers
        â”œâ”€â”€ IconRound.tga       # Circular minimap button icon (128x128)
        â””â”€â”€ Logo.tga            # Full logo (256x256) for the options header and blackout screen

Artwork sources are the `Eagle Eye 20 Icon.svg` and `Eagle Eye 20 Logo.svg` files at the
repository root; `tools/build_textures.py` regenerates the TGA textures from them.

### `.toc` File Header Specification (`EagleEye20.toc`)

    ## Interface: 20506
    ## Title: Eagle Eye |cff00cc9920/20/20|r
    ## Notes: Smart 20-20-20 eye strain timer with combat safety checks for WoW Classic Anniversary (TBC).
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
- Transitions to `PREPARE` when `timeRemaining <= warningDuration` (â†’ 1 minute left).

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
- **Party Notification:** If `announceParty` is enabled and `ns.InGroup()` is true (and not `ns.InRaid()` unless `announceRaid` is toggled), sends the configured message to the `"PARTY"` chat channel.
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
- Subtle header or tooltip displaying `Eagle Eye 20/20/20`, prefixed with the `Icon.tga` glyph.
- Movable (`SetMovable(true)`, `RegisterForDrag("LeftButton")`), clamped to screen (`SetClampedToScreen(true)`), with option to lock position. Saves coordinates (`point, relativePoint, xOfs, yOfs`) in `EagleEye20DB`.
- **Elements:**
  - Countdown Text (`MM:SS`) with configurable Font Face, Font Size, and Outline.
  - Interactive icon/text buttons: **Play/Pause**, **Reset**, and a contextual **Confirm Safe / Snooze** button that appears during `PREPARE` and `READY_WAITING`.
  - 2px bottom status bar reflecting progress and current state color.

### 5.3 Fullscreen Blackout Overlay (`UI_Blackout.lua`)
- Frame Strata: `FULLSCREEN_DIALOG`, covering `UIParent` (`SetAllPoints(UIParent)`).
- Opacity configurable (default `0.95` dark background).
- `Logo.tga` above the title at 80px and 90% alpha.
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
1. **AFK Auto-Reset:** Poll `ns.IsAFK()` once a second (and on `PLAYER_FLAGS_CHANGED` when the client sends it). If the player stays AFK for >= 60 seconds, automatically reset the work timer to `20:00` and log `AUTO_RESET_AFK`.
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
- `/ee20` (empty) â€” Opens Config UI (`Eagle Eye 20/20/20` options panel)
- `/ee20 start` / `/ee20 pause` / `/ee20 reset` â€” Timer controls
- `/ee20 safe` or `/ee20 confirm` â€” Confirms safety and starts the 20s blackout (when in `PREPARE` or `READY_WAITING`)
- `/ee20 snooze` â€” Adds 60 seconds to current timer
- `/ee20 preset` â€” Prints the active preset; `/ee20 preset 30` (or `30/30/20`, `custom`) switches scheme
- `/ee20 log` â€” Toggles the Event Log window
- `/ee20 minimap` â€” Shows or hides the minimap button
- `/ee20 test` â€” Triggers an immediate transition to `PREPARE` (with 5s left) to test warnings, party chat, and blackout flow.

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
            showMinimap = true,         -- minimap button visibility
            minimapAngle = 200,         -- degrees around the minimap rim
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

---

## 9. Future Roadmap & Planned Improvements
The following quality-of-life enhancements are queued for future releases:
1. **Death / Ghost Safety Gate:** Hook `PLAYER_DEAD` / `PLAYER_ALIVE` / `PLAYER_UNGHOST` and verify `UnitIsDeadOrGhost("player")`. When dead or running back to a corpse, hold in `DEAD / GHOST - WAITING` and suppress break prompts.
2. **Repeating Ready Sound Alert:** Add an optional configuration interval (e.g. 30s/60s) to repeat the ready chime when the break is pending out of combat.
3. **SoundKit Audio Resiliency:** Support modern `SOUNDKIT` numeric IDs via `PlaySound(id, "Master")` with fallback to `PlaySoundFile(path, "Master")`.
4. **Tradeskill Batch Crafting Sync:** Monitor `UNIT_SPELLCAST_START` / `UNIT_SPELLCAST_STOP` to surface a `TAKE BREAK NOW` prompt during lengthy tradeskill crafting queues.
5. **Mini-Widget Quick Lock:** Provide a quick shortcut (e.g., right-click drag handle or mini lock toggle) on the widget frame to lock/unlock position directly.
6. **Post-Break Micro-Exercise & Posture Module (Optional):**
   - Pure eye rest is preserved during the 20-second blackout.
   - An optional toggle provides a quick follow-up prompt *after* the break finishes with brief physical resets (neck rolls, shoulder shrugs, hand flexes).
7. **Hourly Hydration & Movement Chime:**
   - Standalone hourly reminder (60 minutes independent of 20-minute eye intervals) prompting the player to drink water, stand up, and reset spine posture.
8. **Soft Dimming / Vignette Visual Mode (Configurable):**
   - Selectable overlay appearance: **Full Blackout** (default 95% black) vs. **Soft Dimming** (~70% dimmed vignette screen) for players who prefer a gentler transition.
9. **Gamification, Streaks & Configurable Compliance Target:**
   - Configurable target compliance rate (defaulting to 90%).
   - Daily and weekly streak tracking persisted in `EagleEye20DB`.
   - Milestone achievements displayed in `UI_Log.lua` (e.g., *Sharp Vision*, *Raid Medic*).
10. **Per-Character & Activity Profiles + Data Broker:**
    - SavedVariables profile architecture (e.g., `Default`, `Raiding`, `Leveling`).
    - Quick-switch commands and options UI dropdown.
    - LibDataBroker (LDB) data feed integration for TitanPanel, ChocolateBar, and ElvUI top/bottom bars.
