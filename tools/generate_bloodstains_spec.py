import json
import os
import sys
import urllib.error
import urllib.request
import time

DEFAULT_MODEL = "deepseek-ai/deepseek-v4.1-flash-1017"
BASE_URLS = ["https://api-cdn.thehive.ai/api/v3", "https://api-va1.thehive.ai/api/v3"]

SPEC_PROMPT = """You are an elite principal software architect specializing in World of Warcraft addon development (Lua 5.1, WoW Client API, frame rendering, combat log, and network protocols).

The user has requested a complete, production-grade technical specification document for a new World of Warcraft addon:
"Bloodstains & Message Stones" (Elden Ring / Souls-like World Marks).

Here is the concept and core mechanics to specify:
1. Concept:
   - When a player dies in the open world, delves, or dungeons, the addon records their location, cause of death, and the last 3-5 seconds of movement/facing/spell casts.
   - Other players running the addon see an ethereal bloodstain or glowing rune in the 3D world (or screen/map projected).
   - Interacting with a bloodstain replays an ethereal ghost of the player mimicking their final seconds and death animation.
   - Players can also scribe "Message Stones" / glowing signs using Elden Ring-style pre-composed template phrases (e.g. "Be wary of elite ahead", "Praise the Sunwell", "Secret cave below", "Liar ahead").
   - Other players can read message runes in the world, and rate them (+1 "Appraise message"). Appraisals notify the author in real-time.

2. How It Works / Technical Requirements:
   - Uses C_ChatInfo.SendAddonMessage / RegisterAddonMessagePrefix across hidden custom channels, guild channels, group/raid channels, or zone broadcast to sync death coordinates and messages.
   - 3D World Markers & In-World Projection / Pinning: Detail how the addon renders bloodstains, rune stones, proximity interaction prompts ("Touch Bloodstain", "Read Message"), and ghost replays given the WoW API's 3D/2D rendering constraints (e.g., WorldFrame screen projection math, C_Map pins, HereBeDragons-Pins / modern map pin mixins, ModelScene / PlayerModel / DressUpModel ghost rendering with transparency/vertex coloring, interaction distance checking).
   - Data Ring Buffer & Telemetry: 10-20 Hz rolling buffer of coordinates (UnitPosition / C_Map.GetPlayerMapPosition), facing (GetPlayerFacing), pitch/yaw, animation/movement states, and COMBAT_LOG_EVENT_UNFILTERED death blow analysis.
   - Compression & Packet Serialization: Bit-packing, string serialization (LibDeflate/LibSerialize patterns), binary encoding to strictly respect the 255-byte chat throttle limit.
   - Message Composer & Grammar Engine: Multi-part template system (Category, Template phrase, Conjunction, Word fillers) avoiding raw offensive chat while mimicking authentic FromSoftware phrasing.
   - Rating & Economy/Feedback: Appraise (+1) / Disparage mechanics, author notifications, visual intensity scaling based on praise count.
   - Storage & Cache: SavedVariables schema, TTL expiration, cache invalidation, anti-spam, deduplication hashes.
   - Edge Cases & Blizzard API Constraints: Instance/combat restrictions on position APIs, combat lockdown (InCombatLockdown()), addon message rate limits and throttling, phasing/sharding/delve zone mapping.

Generate a comprehensive, exhaustive, professional Technical Specification Document in Markdown format.
Include:
- Title & Addon Metadata (Interface versions, TOC structure, folder structure)
- Design Philosophy & Architecture Diagram (Mermaid)
- Telemetry & Death Recording Engine (detailed event sequence, ring buffer structure, death packet format)
- Ghost Replay & In-World Rendering Engine (exact WoW API mechanisms, Model/Frame setup, animation playback, projection math)
- Message Stone / Soapstone Engine (grammar dictionary structure, UI composer, rating feedback loop)
- Networking, P2P Synchronization & Protocol Spec (packet types, byte layout, channel strategy, chunking/reassembly, rate-limiting)
- SavedVariables & Data Storage Schema (Lua table definitions)
- User Interface & UX Flow (HUD prompts, interaction frames, map pins)
- Security, Privacy & Blizzard API Compliance (anti-exploit, instance safety, spam mitigation)
- Implementation Roadmap & File-by-File Breakdown

Write out the entire specification with full detail, Lua code examples/snippets where appropriate, and exact data structures. Do not truncate or leave placeholders.
"""

def stream_from_hive(base_url, model, output_file):
    api_key = os.environ.get("HIVE_API_KEY") or os.environ.get("HIVE_SECRET_KEY")
    if not api_key:
        print("Error: HIVE_API_KEY environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    url = f"{base_url.rstrip('/')}/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "User-Agent": "antigravity-hive-spec-builder/1.0"
    }

    payload = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": "You are a world-class principal WoW addon architect and systems designer. You produce rigorous, production-grade technical specification documents."
            },
            {
                "role": "user",
                "content": SPEC_PROMPT
            }
        ],
        "stream": True,
        "temperature": 0.2
    }

    print(f"Connecting to Hive ({url}) with model {model}...")
    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")

    total_chars = 0
    with urllib.request.urlopen(req, timeout=300) as resp:
        with open(output_file, "w", encoding="utf-8") as out:
            for line in resp:
                decoded = line.decode("utf-8").strip()
                if not decoded:
                    continue
                if decoded.startswith("data: "):
                    content = decoded[6:]
                    if content == "[DONE]":
                        break
                    try:
                        chunk = json.loads(content)
                        choices = chunk.get("choices", [])
                        if choices:
                            delta = choices[0].get("delta", {}).get("content", "")
                            if delta:
                                out.write(delta)
                                out.flush()
                                total_chars += len(delta)
                    except json.JSONDecodeError:
                        continue
    print(f"Successfully streamed {total_chars} characters to {output_file}")
    return total_chars

if __name__ == "__main__":
    out_path = os.path.join(os.getcwd(), "BLOODSTAINS_MESSAGE_STONES_SPEC.md")
    success = False
    for base_url in BASE_URLS:
        try:
            print(f"Trying base URL: {base_url}")
            chars = stream_from_hive(base_url, DEFAULT_MODEL, out_path)
            if chars > 500:
                success = True
                break
        except Exception as e:
            print(f"Error on {base_url}: {e}", file=sys.stderr)
            time.sleep(2)
            
    if not success:
        print("Falling back to zai-org/glm-5.3-flash...")
        try:
            chars = stream_from_hive(BASE_URLS[0], "zai-org/glm-5.3-flash", out_path)
            if chars > 500:
                success = True
        except Exception as e:
            print(f"Fallback failed: {e}", file=sys.stderr)
            sys.exit(1)
