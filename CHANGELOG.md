# Changelog

All notable changes to Eagle Eye 20/20/20 are documented here.

## 0.20.0-alpha-tbc (TBC Anniversary port)

### Changed

- **Target client** — ported to **WoW Classic Anniversary (The Burning Crusade)**, Interface `20506`. The addon's feature-detection layer (`ns.NewFrame` backdrop shim, `ns.InGroup`/`ns.InRaid`, `ns.IsAFK` polling, `Settings.*` options registration with `InterfaceOptions_*` fallbacks, `PlaySound` kit-ID handling) already covers this client's modern API surface, so no behavioral code changes were required.
- Version strings bumped to `0.20.0-alpha-tbc` (TOC metadata, `ns.version`, options footer, log header).

### Compatibility

- WoW Classic Anniversary client (TBC), Interface `20506`.
- No addon dependencies; SavedVariables remain `EagleEye20DB`.

## 0.20.0-alpha

Cumulative changes since `0.10.0-beta`. (`0.11.0-alpha` was an intermediate build containing most of the feature work below.)

### Added

- **Death / Ghost safety gate** — the break is held while dead or corpse-running, showing `DEAD / GHOST - WAITING`. An active break is interrupted on death and returns to the safety gate.
- **Vehicle safety gate** — holds the break while in a vehicle, showing `IN VEHICLE - WAITING`.
- **Cinematic safety gate** — holds the break during cutscenes, showing `CINEMATIC - WAITING`, and interrupts an active break when a cinematic starts.
- **Hold toggles** — new `Hold break while dead` and `Hold break in vehicle` options (both enabled by default).
- **Soft Dimming Vignette** — alternative break visual with smooth edge shading, selectable via the new `Break visual style` dropdown.
- **Break screen opacity slider** — single dynamic slider that adjusts solid blackout opacity or vignette dimming depending on the selected style.
- **Repeating ready chime** — optional repeat interval for the ready alert while waiting out of combat (Off, 30s, 60s, 2m). Defaults to 30 seconds.
- **Widget lock** — `[U]`/`[L]` button on the floating widget, `Shift+Right-Click` shortcut, and `/ee20 lock` command.
- **Version display** — version shown in the options footer, minimap tooltip, addon compartment tooltip, and event log header.
- **TOC metadata** — added `## X-Version` and `## X-Category` for addon manager discovery.
- **Simulator harness** — `EagleEye_Simulator.html` for offline UI testing.

### Changed

- Safety checks are now centralized in a single context check covering combat, death, vehicles, and cinematics.
- Widget status text now reports the specific blocking reason instead of only combat.
- Widget tooltips refresh immediately on lock/unlock instead of waiting for mouse-out.
- Options panel layout expanded to fit the new controls; minimap shape moved to the first column.
- README updated with the new safety gates, visual modes, and slash commands.

### Fixed

- **ESC key taint block** — removed `UISpecialFrames` registration on `EagleEye20Blackout` which caused `UIParentPanelManager.lua:1109` to taint `ToggleGameMenu()`, resulting in `ADDON FORBIDDEN: SpellStopTargeting()` and `ClearTarget()` when pressing Escape.
- **Keybinding category taint** — corrected `category` to `ADDONS` and set `header="EAGLEEYE20"` in `Bindings.xml` to prevent `Keybindings.lua:221` taint.
- **Settings taint** — removed the `RegisterAddOnCategory` call on subcategories, which caused `ADDON_ACTION_BLOCKED` errors.
- Gradient textures fall back gracefully on clients without gradient support, preventing a blank or solid-only overlay.

### Compatibility

- WoW Classic Anniversary client (TBC), Interface `20506`.
- No addon dependencies; SavedVariables remain `EagleEye20DB`.
