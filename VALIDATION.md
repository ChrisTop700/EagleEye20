# EagleEye20 Quality Assurance & Validation Plan

This document outlines the step-by-step test matrix to verify all states, UI components, emergency safety gates, audio alerts, and MMO context features for **Eagle Eye 20/20/20** (`EagleEye20`).

---

## 60-Second Quick Smoke Test
Use this rapid sequence after making changes or deploying builds:
1. Type `/ee20 test` &rarr; Timer jumps to `00:05`, switches to Amber, Raid Warning sound plays.
2. Click `SAFE NOW` (or press custom keybind) &rarr; Fullscreen Blackout Frame fades in over 0.5s, countdown begins at `20`.
3. Press <kbd>ESC</kbd> (or double-click) &rarr; Overlay clears immediately, native UI clicks work freely.
4. Type `/ee20 log` &rarr; Verify `TEST`, `BREAK_STARTED`, and `ABORTED_MANUAL` entries exist with timestamps.
5. Click `RST` &rarr; Work timer returns cleanly to `20:00`.

---

## Phase 1: Boot, UI Presence & Clean Load

| # | Test Case | Action / Steps | Expected Result |
|---|---|---|---|
| **1.1** | **Clean Load & SavedVariables** | Log in or run `/reload`. Check chat window. | Addon loads silently; chat outputs `[EagleEye20] Eagle Eye 1.0.0 loaded (20/20/20)`. No Lua error dialogs. |
| **1.2** | **Mini-Widget Initial State** | Inspect screen center/default position. | Compact rectangular frame is visible with `EAGLE EYE` header, round icon, `20:00` in teal, `II`, `RST`, and `LOG` buttons, and an empty progress bar at the bottom. |
| **1.3** | **Minimap Button** | Inspect the minimap border. | Round Eagle Eye icon sits on the minimap edge. Hovering displays the tooltip with status. Dragging moves it around the rim smoothly. |
| **1.4** | **Addon Compartment** | Open native Addon Compartment (top right of screen). | `Eagle Eye 20/20/20` is listed with its icon. Left-clicking opens the settings menu. |

---

## Phase 2: Core State Engine & Timer Controls

| # | Test Case | Action / Steps | Expected Result |
|---|---|---|---|
| **2.1** | **Countdown Progress** | Observe widget for 10–15 seconds. | Time counts down smoothly (e.g. `19:59`, `19:58`), progress bar slowly begins to fill from left to right. |
| **2.2** | **Pause & Resume** | Click `II` on widget or type `/ee20 pause`. | Button changes to `>`, timer text turns grey (`PAUSED`), countdown halts. Clicking `>` or typing `/ee20 start` resumes. |
| **2.3** | **Manual Reset** | Let timer count down a few seconds, then click `RST` or type `/ee20 reset`. | Timer resets back to full cycle (`20:00`) and resumes green/teal state. |
| **2.4** | **Snooze Functionality** | Type `/ee20 snooze 60`. | 60 seconds are added to the timer; event logged as `SNOOZED`. |

---

## Phase 3: Fast-Path Transition & Safety Gate (`/ee20 test`)

| # | Test Case | Action / Steps | Expected Result |
|---|---|---|---|
| **3.1** | **Prepare State (Warning)** | Type `/ee20 test`. | Timer immediately jumps to `00:05`, color shifts to **Amber**, Raid Warning sound chimes, and the widget expands with `SAFE NOW`, `+1M`, and `+2M` buttons. |
| **3.2** | **Ready Waiting State** | Wait for the 5 seconds to expire (reaches `00:00`). | Timer holds at `00:00`, shifts to **Coral Red**, border pulses gently, Ready Check chime sounds. |
| **3.3** | **Combat Suppression (Safety Gate)** | While in `READY_WAITING`, hit a training dummy or pull a mob to enter combat. | `SAFE NOW` and snooze buttons immediately hide; widget shows red `"IN COMBAT - WAITING"` banner. Leaving combat restores the buttons. |

---

## Phase 4: Break Execution & Emergency Escape Hatches

| # | Test Case | Action / Steps | Expected Result |
|---|---|---|---|
| **4.1** | **Normal Break Flow** | Out of combat, click `SAFE NOW` (or press keybind). | Break start sound plays, party announcement fires (if in party), and fullscreen Blackout Frame fades in (dark overlay, centered logo, `"LOOK 20 FEET AWAY"`, 20s countdown). |
| **4.2** | **Natural Completion** | Let the 20 seconds count down to 0 without touching keyboard/mouse. | Level-up chime sounds (critical audio cue to return vision to screen), overlay fades out cleanly, work timer resets to full cycle (`20:00`), event logged as `BREAK_COMPLETED`. |
| **4.3** | **Emergency Escape via ESC** | Type `/ee20 test`, confirm `SAFE NOW`, then press <kbd>ESC</kbd>. | Overlay immediately aborts, break closes cleanly, stats log `ABORTED_MANUAL`. Native UI clicks and movement work immediately without sticking. |
| **4.4** | **Emergency Escape via Double-Click** | Start a break, then rapid double-click the dark screen. | Overlay immediately aborts and disappears. |
| **4.5** | **Emergency Combat Interrupt** | Start a break, then have a mob aggro you (or duel partner attack you). | `PLAYER_REGEN_DISABLED` fires: blackout instantly disappears, combat cancel sound plays, state returns safely to `READY_WAITING`, event logged as `INTERRUPTED_COMBAT`. |
| **4.6** | **Panic Recovery Command** | In case of any UI lock test, type `/ee20 panic`. | Clears the blackout frame and input traps immediately. |

---

## Phase 5: Smart MMO Context Handlers

| # | Test Case | Action / Steps | Expected Result |
|---|---|---|---|
| **5.1** | **Flight Path (Taxi) Prompt** | Use `/ee20 snooze` or `/ee20 preset custom` so time remaining is `< 5:00`. Board a flight path. | Header text changes to amber `"TAKE BREAK NOW?"`, `BREAK NOW` button appears on widget allowing safe break while in flight. |
| **5.2** | **AFK Auto-Pause & Auto-Reset** | Type `/afk` while timer is running. | Addon detects AFK: timer automatically pauses (`AUTO_PAUSE_AFK`). After 60 seconds AFK, work timer resets to `20:00` (`AUTO_RESET_AFK`). Clearing `/afk` resumes the clock. |
| **5.3** | **Inn / Resting Auto-Start** | Enable `"Auto-start while resting"` in `/ee20`. Walk into an inn (character icon shows `zzz`). Run `/ee20 test`. | Upon reaching `00:00`, break automatically confirms and starts without requiring button click. |

---

## Phase 6: Settings, Keybinds & Data Persistence

| # | Test Case | Action / Steps | Expected Result |
|---|---|---|---|
| **6.1** | **Keybinds Menu** | Open game **Options &rarr; Keybindings &rarr; AddOns &rarr; Eagle Eye 20/20/20**. | Three distinct actions exist: `Confirm Safe / Start Break`, `Snooze Pending Break`, and `Pause / Resume Timer`. Assign a key (e.g. <kbd>F12</kbd>) and test trigger. |
| **6.2** | **Settings Configuration** | Type `/ee20`. Modify widget scale (e.g. `1.2x`), font size, preset (`30/30/20`), and toggle lock. | Changes apply in real time. Locked widget cannot be dragged; presets change the work/rest numbers immediately. |
| **6.3** | **Event Log & Stats Viewer** | Click `LOG` button on widget or type `/ee20 log`. | Event log window opens. Displays sessions stats, lifetime stats, compliance percentage, and timestamped FIFO logs (`[HH:MM:SS] BREAK_COMPLETED`, etc.). Mousewheel scrolls smoothly. |
| **6.4** | **Log Clear & Reload Persistence** | Click `"Clear log"` in log window, then `/reload`. | Log history is empty, stats persist, widget position remains locked where you saved it in `EagleEye20DB`. |
