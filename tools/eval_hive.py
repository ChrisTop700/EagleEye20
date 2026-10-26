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
You are a senior World of Warcraft addon architect and UX designer.
We are reviewing the next features to implement for our WoW addon: **Eagle Eye 20/20/20 (EagleEye20)**.

### Background:
- **Client**: World of Warcraft Forever (modern client API, interface 16001, Wrath of the Lich King era content).
- **Core Functionality**: Combat-aware 20-20-20 eye strain timer. It runs a 5-state engine (RUNNING, PREPARE, READY_WAITING, RESTING blackout, PAUSED).
- **Existing Features (v0.10.0-beta)**:
  - Presets (20/20/20, 30/30/20, 45/45/20, 60/60/20, Custom)
  - Combat safety gate (holds when in combat, interrupts blackout if combat starts)
  - AFK detection & auto-reset after 60s
  - Flight path (taxi) early break suggestion
  - Resting/Inn auto-start option
  - Party/Raid announcements
  - Draggable modern flat mini-timer widget
  - Minimap button
  - Fullscreen blackout overlay with countdown and cancel handlers
  - Event log and session/lifetime stats window (compliance %, snooze, combat interrupts)

### Planned Roadmap Candidates:
1. **Death / Ghost State Safety Gate**: Check `UnitIsDeadOrGhost("player")`. When dead or running back to corpse, show "DEAD / GHOST - WAITING" and suppress break prompts.
2. **Repeating Ready Alert Sound**: Optional repeat interval (e.g. 30s/60s) for the ready chime while holding in READY_WAITING out of combat.
3. **Mini-Widget Quick Lock / Interaction Polish**: Add right-click toggle or padlock icon directly on the widget to lock/unlock position without opening Settings; plus tooltip/hover polish.
4. **Soft Dimming / Vignette Visual Mode**: Configurable overlay style — solid 95% blackout vs 70% soft vignette dimming for players who want a gentler screen break.
5. **Tradeskill & Batch Crafting Detection**: Hook `UNIT_SPELLCAST_START` / `UNIT_SPELLCAST_STOP` to offer a "TAKE BREAK NOW" prompt during lengthy crafting queues.
6. **Hourly Health & Hydration Reminders**: Independent 60-minute reminder for water, standing up, and posture checks.
7. **Post-Break Micro-Exercise & Posture Routine**: Optional short guidance *after* the 20s eye break finishes with quick neck/shoulder/wrist stretch cues.
8. **Gamification & Compliance Streaks**: Configurable target (e.g. 90%), daily/weekly streak tracking, fun milestone badges in the log window.
9. **LibDataBroker (LDB) Feed & TitanPanel / ChocolateBar / ElvUI Support**: Standard data feed for top/bottom bar addons.
10. **Per-Character & Activity Profiles**: SavedVariables profile architecture (e.g., Raiding, Leveling, Crafting) with quick-switching.

### Request:
Please evaluate and organize these feature candidates (plus any high-value additions you identify) into:
1. **Tier 1: High-Impact & Quick Wins** (Low effort, high polish / immediate safety improvement for daily play).
2. **Tier 2: Immersion & Visual / Audio Experience** (Improves how breaks look, feel, and sound).
3. **Tier 3: MMO Ergonomics & Holistic Wellness** (Extending beyond eye rest to physical wellness during long sessions).
4. **Tier 4: Advanced Addon Ecosystem & Power User Features** (Profiles, LDB, integrations).

For each feature, briefly provide:
- **Why it matters** (Player pain point or UX delight).
- **Implementation complexity** (Low / Medium / High).
- **Key API / technical consideration** for WoW 3.3.5a / modern 16001 client.
- **Recommendation score** (1 to 5 stars).

End with a concise recommendation on the top 2-3 features we should build first in our next sprint.
"""

payload = {
    "model": "deepseek-ai/deepseek-v4.1-flash-1017",
    "messages": [
        {"role": "system", "content": "You are an expert World of Warcraft addon architect, specialized in Lua 5.1, WoW client APIs, and ergonomic gaming UX."},
        {"role": "user", "content": prompt}
    ],
    "stream": False
}

out_path = r"C:\Users\chris\repo\EagleEye20\tools\hive_eval_output.md"
sys.stdout.write("Sending request to Hive AI (non-streaming)...\n")
sys.stdout.flush()

data = json.dumps(payload).encode("utf-8")
req = urllib.request.Request(url, data=data, headers=headers, method="POST")

with urllib.request.urlopen(req, timeout=60) as resp:
    body = resp.read().decode("utf-8")
    res_json = json.loads(body)
    content = res_json["choices"][0]["message"]["content"]
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(content)
    sys.stdout.write(f"Successfully received and saved {len(content)} characters to {out_path}\n")
    sys.stdout.flush()
