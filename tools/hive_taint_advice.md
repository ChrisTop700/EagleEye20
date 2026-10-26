## Root cause

The one that causes this taint popup is **item 5, the Settings registration block** — specifically this line:

```lua
Settings.RegisterAddOnCategory(sub)
```

`Settings.RegisterAddOnCategory(category)` is for a **top-level addon category**. A category created by `Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, name)` is already attached to its parent category. You must **not** register the subcategory as an addon category.

That misregistration taints Blizzard’s Settings/Addon Manager path. When the game opens the Addon Manager or reloads and Blizzard’s secure Settings code runs, it hits the tainted category and throws:

> EagleEye20 has been blocked from an action only available to the Blizzard UI...

### Correct fix

```lua
local ADDON_NAME = "EagleEye20"
local addonCategory

local function RegisterEagleEyePanel(panel, parentCategory)
    if not panel.name or panel.name == "" then
        panel.name = ADDON_NAME
    end

    if not (Settings and Settings.RegisterCanvasLayoutCategory) then
        return nil
    end

    -- Subcategory: DO NOT call Settings.RegisterAddOnCategory on it.
    if parentCategory then
        return Settings.RegisterCanvasLayoutSubcategory(
            parentCategory, panel, panel.name
        )
    end

    -- Top-level addon category: register once.
    if not addonCategory then
        addonCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)

        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(addonCategory)
        end
    end

    return addonCategory
end
```

Key rules:

- Top-level category: `RegisterCanvasLayoutCategory` + `RegisterAddOnCategory`.
- Subcategory: only `RegisterCanvasLayoutSubcategory`; **no** `RegisterAddOnCategory`.
- Register once, preferably during addon load / player login, not from UI callbacks.
- Do not register a subcategory under another addon’s category unless you are certain that is supported/allowed.

## What is probably not causing it

These are normal and are not protected actions by themselves:

1. `table.insert(UISpecialFrames, "EagleEye20Blackout")`  
   Standard ESC-close behavior. Not the taint source. Just ensure the frame name exists and you do not insert `nil`.

2. `SetPropagateKeyboardInput` / `EnableKeyboard` on your own frame  
   Fine on your own non-Blizzard frame. Disable keyboard input when the frame hides.

3. Adding your own key to `StaticPopupDialogs`  
   Fine, as long as you only add/use `EAGLEEYE20_CONFIRM_OVERWRITE` and do not modify Blizzard popup entries.

4. `UIDropDownMenu_*`  
   This can be a taint source if misused, but it is not the likely cause here. If you use it:
   - Give every dropdown a unique global frame name, e.g. `EagleEye20OverwriteDropdown`.
   - Never reuse Blizzard dropdown names such as `DropDown`, `StaticPopup1`, etc.
   - Do not monkey-patch `UIDropDownMenu_*` or the `UIDropDownMenu` table.
   - Do not initialize a Blizzard-owned dropdown frame.
   - Prefer the modern `Menu` API or `Settings.CreateDropdown` if available.

6. Binding globals  
   `BINDING_HEADER_EAGLEEYE20`, `BINDING_NAME_EAGLEEYE20_*` are safe metadata strings. Not the cause.

7. `SetFrameStrata("HIGH")` / `SetFrameLevel(100)`  
   Safe on your own frame. Not the cause.

If the popup persists after fixing the subcategory registration, enable taint logging and check the log:

```text
/console taintLog 2
/reload
```

Then inspect `World of Warcraft/Logs/taint.log` for `EagleEye20` and the first Blizzard frame/function it touches.

## Where to put the version at the bottom of the options screen

Create a small `FontString` on your own options panel and anchor it to the bottom-right or bottom-center. Read the version from the TOC rather than hardcoding it.

```lua
local ADDON_NAME = "EagleEye20"

local function GetEagleEyeVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(ADDON_NAME, "Version") or "?"
    end
    return "?"
end

local function AddVersionFooter(panel)
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12)
    fs:SetText(("EagleEye20 v%s"):format(GetEagleEyeVersion()))
    return fs
end
```

Call `AddVersionFooter(panel)` after creating your panel. If you prefer bottom-left:

```lua
fs:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12)
```

Do not anchor it to a Blizzard secure frame. Anchor to your own panel.

## TOC metadata / addon manager recognition

Addon managers read the version from the TOC, not from your Lua UI footer. Put the version in the `.toc` file:

```toc
## Interface: 16001
## Title: EagleEye20
## Version: 1.2.3
## X-Version: 1.2.3
## Author: YourName
## Notes: Eagle Eye 20/20/20 helper
## SavedVariables: EagleEye20DB
## IconTexture: Interface\AddOns\EagleEye20\icon
```

Use `## Version:` as the canonical field. `## X-Version:` is optional compatibility metadata that some addon managers/tools may read; if you include it, keep it identical to `## Version:`. Do not put the version only in `X-Version`, because WoW itself exposes the `Version` TOC field via `GetAddOnMetadata` / `C_AddOns.GetAddOnMetadata`.

For addon-manager-specific metadata:

```toc
## X-Curse-Project-ID: 123456
## X-WoWI-ID: 12345
## X-Wago-ID: abc123
```

Use only the IDs relevant to where you publish.

If you support multiple game flavors, use flavor-specific TOCs/interfaces rather than one ambiguous TOC, for example:

```toc
## Interface-Retail: 16001
## Interface-Classic: 11507
```

and keep the TOC filename/folder naming consistent with the flavor convention your packager uses.

## Summary

- Fix: remove `Settings.RegisterAddOnCategory(sub)` for subcategories.
- Register only top-level categories with `Settings.RegisterAddOnCategory`.
- The other listed items are not the taint source unless the dropdown code is actually touching shared/Blizzard `UIDropDownMenu` internals.
- Put the in-game version text at the bottom of your own settings panel.
- Put the authoritative version in the TOC under `## Version:`, optionally mirror it in `## X-Version:`, and add Curse/WoWI/Wago IDs as needed.