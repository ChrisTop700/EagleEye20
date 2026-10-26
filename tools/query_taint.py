import sys
import os
import json
import urllib.request

api_key = os.environ.get("HIVE_API_KEY") or os.environ.get("HIVE_SECRET_KEY")
url = "https://api-cdn.thehive.ai/api/v3/chat/completions"
headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json",
    "User-Agent": "antigravity-hive-skill/1.0"
}

prompt = """
We have a World of Warcraft addon (EagleEye20) running on interface 16001 (modern client).
When the player opened Addon Manager (Addon Manargl / ACP) or reloaded, they got the popup:
"EagleEye20 has been blocked from an action only available to the Blizzard UI. You can disable this addon and reload the UI."

Here are the potential areas in our addon:
1. `table.insert(UISpecialFrames, "EagleEye20Blackout")`
2. `f:SetPropagateKeyboardInput(true/false)` and `f:EnableKeyboard(true/false)` on `EagleEye20Blackout` (a frame with strata FULLSCREEN_DIALOG).
3. `StaticPopupDialogs["EAGLEEYE20_CONFIRM_OVERWRITE"]` modifying global `StaticPopupDialogs`.
4. `UIDropDownMenu_*` calls: `CloseDropDownMenus()` or `UIDropDownMenu_Initialize` without unique names or touching UIDropDownMenu.
5. In `UI_Config.lua`:
```lua
    if Settings and Settings.RegisterCanvasLayoutCategory then
        if parentCategory then
            local sub = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, panel.name)
            if Settings.RegisterAddOnCategory then
                Settings.RegisterAddOnCategory(sub)
            end
            return sub
        end
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        if Settings.RegisterAddOnCategory then
            Settings.RegisterAddOnCategory(category)
        end
        return category
    end
```
6. In `Core.lua`:
```lua
BINDING_HEADER_EAGLEEYE20 = "Eagle Eye 20/20/20"
BINDING_NAME_EAGLEEYE20_CONFIRMSAFE = "Confirm Safe / Start Break"
BINDING_NAME_EAGLEEYE20_SNOOZE = "Snooze Pending Break"
BINDING_NAME_EAGLEEYE20_PAUSERESUME = "Pause / Resume Timer"
```
7. In `UI_Widget.lua`:
`f:SetFrameStrata("HIGH")`, `f:SetFrameLevel(100)`

Which of these causes "EagleEye20 has been blocked from an action only available to the Blizzard UI", and how should we fix it?
Also, where should the version number be placed at the bottom of the options screen, and how do we ensure the version is recognized by all addon managers (TOC metadata, X-Version, etc.)?
"""

payload = {
    "model": "deepseek-ai/deepseek-v4.1-flash-1017",
    "messages": [
        {"role": "system", "content": "You are a World of Warcraft client engine and secure execution / taint expert."},
        {"role": "user", "content": prompt}
    ],
    "stream": False
}

data = json.dumps(payload).encode("utf-8")
req = urllib.request.Request(url, data=data, headers=headers, method="POST")

with urllib.request.urlopen(req, timeout=60) as resp:
    body = resp.read().decode("utf-8")
    res_json = json.loads(body)
    content = res_json["choices"][0]["message"]["content"]
    with open(r"C:\Users\chris\repo\EagleEye20\tools\hive_taint_advice.md", "w", encoding="utf-8") as f:
        f.write(content)
    print("Received Hive advice!")
