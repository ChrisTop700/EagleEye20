# Taint Debugging Guide — "blocked from an action only available to the Blizzard UI"

This popup (the `ADDON_ACTION_BLOCKED` dialog) means addon-tainted code
attempted a protected Blizzard function. It most often surfaces when you press
ESC, close a menu, or interact with the GameMenu/Interface Options panel,
because that is when the secure UI executes the bindings and menu-close code
that taint has poisoned.

This guide covers the **WotLK 3.3.5a port** (`EagleEye20-WotLK`). The 3.3.5a
client has no `Settings` API and no `C_Timer`, so the modern-client taint paths
around `Settings.OpenToCategory` do not apply here; the binding and
`UISpecialFrames` paths do.

## What was fixed in this addon

| Location | Problem | Fix |
|---|---|---|
| `UI_Blackout.lua` — `UISpecialFrames` | `table.insert(UISpecialFrames, "EagleEye20Blackout")` made Blizzard's `CloseWindows()` read `_G["EagleEye20Blackout"]` on every ESC keypress, tainting window management. | Removed the `UISpecialFrames` registration; the overlay already captures and handles ESC directly via its `OnKeyDown` script. |
| `Bindings.xml` — binding category | `category="BINDING_HEADER_EAGLEEYE20"` tainted Blizzard's keybinding code because headers are not valid categories. | Use `header="EAGLEEYE20"` and no `category` attribute (3.3.5a has no `ADDONS` category). |
| `UI_Config.lua` — `ApplySafeKey` via `StaticPopup.OnAccept` | `SetBinding`/`SaveBindings` were called from the popup's `OnAccept`, which is **not** a hardware event. Binding-system taint breaks ESC and the game menu. | The overwrite confirm now stashes the key; the actual bind happens on the next physical click of the Safe Key button. |
| `UI_Config.lua` — keybind capture listener | Captured keys propagated into the secure key stream. | `EnableKeyboard(true)` on capture, `SetPropagateKeyboardInput(false)` (when available) to swallow the grabbed key, `EnableKeyboard(false)` on hide. |
| `UI_Config.lua` — `StaticPopupDialogs` | The global `StaticPopupDialogs` table itself was reassigned instead of only adding our key. | Only our own key is assigned, and only if it is not already defined. |

Already fixed in an earlier release (commit `6d6ed0a`): the
`Settings.RegisterAddOnCategory(subcategory)` misregistration from
`tools/hive_taint_advice.md`.

## How to debug if the popup comes back

### 1. In-game block reporter (built in)

The addon listens for `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN` and
prints the exact protected function to chat the moment it happens:

```
EagleEye20 taint block: tried to call SetBinding (see tools/taint_debugging.md to trace it)
```

Type `/ee20 taint` for the session's block history. The same entries are
written to the event log as `TAINT_BLOCKED`.

### 2. Blizzard taint log (full call chain)

```
/console taintLog 2
/reload
```

Reproduce the popup, then inspect:

```
World of Warcraft/Logs/taint.log
```

Search for `EagleEye20`. The log shows the tainted function, the Blizzard
function that rejected it, and the call chain — the first addon frame in the
chain is your culprit.

### 3. Addon Exhaustion Method (bisect)

If `taint.log` is inconclusive, halve the addon list:

1. Disable half your addons, `/reload`.
2. If the popup is gone, the culprit is in the disabled half; if still there, it is in the enabled half.
3. Repeat on the shrinking set.

Note the popup names the addon that was *running* when the block hit, which is
not always the addon that *caused* the taint — a tainted frame created by
addon A can block when Blizzard code (running "as" addon B) touches it later.

### 4. Rules that keep this addon taint-free

- Never call `SetBinding`, `SaveBindings`, `ToggleGameMenu`, `Logout`, `Quit`,
  `UseAction`, `CastSpell`, or `TargetUnit` outside a direct hardware-event
  handler (`OnClick`, `OnKeyDown` wired to real input).
- Never call protected APIs from `OnUpdate`, event handlers, or StaticPopup
  accept/cancel callbacks.
- Register Interface Options panels once, at init, with
  `InterfaceOptions_AddCategory`; express subcategories with the `panel.parent`
  name string.
- Only add keys to `StaticPopupDialogs`; never reassign the table.
- Keep your own frames' keyboard input off unless actively capturing a key,
  and always `SetPropagateKeyboardInput` explicitly when the API exists.
- Do not add addon frames to `UISpecialFrames`; handle ESC in `OnKeyDown`.

## Quick test for the ESC path

1. `/reload`
2. Press ESC — GameMenu must open, no popup.
3. `/ee20` — Interface Options open; press ESC — closes, no popup.
4. `/ee20 test` → `SAFE NOW` → ESC — overlay aborts, no popup.
5. Options → capture a Safe Key already bound elsewhere (e.g. `F12`) → confirm overwrite → click the Safe Key button once more.
6. Press ESC again — no popup, bindings still work.
