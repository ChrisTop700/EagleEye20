# Taint Debugging Guide — "blocked from an action only available to the Blizzard UI"

This popup (the `ADDON_ACTION_BLOCKED` dialog) means addon-tainted code
attempted a protected Blizzard function. It most often surfaces when you press
ESC, close a menu, or interact with the GameMenu/Settings panel, because that
is when the secure UI executes the bindings and menu-close code that taint has
poisoned.

## What was fixed in this addon

| Location | Problem | Fix |
|---|---|---|
| `UI_Config.lua` — `ApplySafeKey` via `StaticPopup.OnAccept` | `SetBinding`/`SaveBindings` were called from the popup's `OnAccept`, which is **not** a hardware event. Binding-system taint breaks ESC and the game menu. | The overwrite confirm now stashes the key; the actual bind happens on the next physical click of the Safe Key button. |
| `UI_Config.lua` — keybind capture listener | Listener never enabled its keyboard, and captured keys propagated into the secure key stream. | `EnableKeyboard(true)` on capture, `SetPropagateKeyboardInput(false)` to swallow the grabbed key. |
| `UI_Config.lua` — `ns.OpenConfig` | `C_Timer.After(0.1, ...)` re-issued `Settings.OpenToCategory` from a timer callback — a non-secure context re-opening a secure panel right after ESC closed it. | Removed the deferred re-open. |
| `UI_Config.lua` — `StaticPopupDialogs` | The global `StaticPopupDialogs` table itself was reassigned instead of only adding our key. | Only our own key is assigned. |

Already fixed in an earlier release (commit `6d6ed0a`): the
`Settings.RegisterAddOnCategory(subcategory)` misregistration from
`tools/hive_taint_advice.md`.

## How to debug if the popup comes back

### 1. In-game block reporter (built in)

The addon now listens for `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN`
and prints the exact protected function to chat the moment it happens:

```
EagleEye20 taint block: tried to call SetBinding (see tools/taint_debugging.md to trace it)
```

Type `/ee20 taint` for the session's block history.

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

- Never call `SetBinding`, `SaveBindings`, `ToggleGameMenu`,
  `Settings.OpenToCategory`, `Logout`, `Quit`, `UseAction`, `CastSpell`, or
  `TargetUnit` outside a direct hardware-event handler (`OnClick`,
  `OnKeyDown` wired to real input).
- Never call protected APIs from `C_Timer.After`, `OnUpdate`, event handlers,
  or StaticPopup accept/cancel callbacks.
- Register Settings categories once, at init: top-level with
  `RegisterCanvasLayoutCategory` + `RegisterAddOnCategory`; subcategories only
  with `RegisterCanvasLayoutSubcategory`.
- Only add keys to `StaticPopupDialogs`; never reassign the table.
- Keep your own frames' keyboard input off unless actively capturing a key,
  and always `SetPropagateKeyboardInput` explicitly.

## Quick test for the ESC path

1. `/reload`
2. Press ESC — GameMenu must open, no popup.
3. `/ee20` — settings open; press ESC — closes, no popup.
4. `/ee20 test` → `SAFE NOW` → ESC — overlay aborts, no popup.
5. Settings → capture a Safe Key already bound elsewhere (e.g. `F12`) → confirm overwrite → click the Safe Key button once more.
6. Press ESC again — no popup, bindings still work.
