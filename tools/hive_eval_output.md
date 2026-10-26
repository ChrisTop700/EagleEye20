Assumptions: keep one central state machine/scheduler, guard all modern `C_*` APIs with 3.3.5a fallbacks, never manipulate protected frames in combat, and version the SavedVariables schema. I placed the repeating ready chime in Tier 2 by theme, but it is still a near-term quick win.

## Tier 1 — High-Impact & Quick Wins

| Feature | Why it matters | Complexity | Key API / technical consideration | Score |
|---|---|---|---|---|
| **Death / Ghost Safety Gate** (#1) | Prevents break overlays, prompts, sounds, and party announcements while dead or ghost-running. Avoids “nagging” during the worst possible moment and prevents false compliance stats. | Low | `UnitIsDeadOrGhost("player")`; `PLAYER_DEAD`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`, `PLAYER_ENTERING_WORLD`. Add a `WAITING_DEAD` state, preserve remaining timer, suppress overlay/sounds/announces, resume safely when alive. | ★★★★★ |
| **Mini-Widget Quick Lock / Tooltip Polish** (#3) | Stops accidental dragging during combat/UI movement and gives direct control without opening Settings. High perceived polish. | Low | `SetMovable`, `RegisterForDrag`, `StartMoving` / `StopMovingOrSizing`, `GetScreenWidth/Height`, `GameTooltip`. Save lock state and position, clamp to screen, and only enable drag when unlocked. No protected-frame issues. | ★★★★★ |
| **Pre-Break Countdown / Warning** *(new)* | A surprise fullscreen blackout is the biggest UX complaint risk. A 10s warning lets the player finish a cast, loot, or interaction and reduces combat interruptions. | Low | Extend the state engine with a `PREPARE` countdown ticker; show a small non-modal warning frame; play a soft chime. Skip/abort if combat, dead, vehicle, cinematic, or disabled. Use `C_Timer` fallback to OnUpdate for 3.3.5a. | ★★★★★ |
| **Context Safety Gates: vehicle / cinematic / pet battle / instance** *(new)* | Avoids blackout when the player has restricted control or is in a cinematic. Especially important for Wrath vehicle quests and modern-client edge cases. | Low–Medium | `UnitInVehicle` / `UnitHasVehicleUI` with compatibility guard; `InCinematic()` or `CinematicFrame:IsShown()`; `C_PetBattles.IsInBattle()` guarded because 3.3.5a has no pet battles; `IsInInstance()` for optional instance-aware deferral. | ★★★★☆ |

## Tier 2 — Immersion, Visual & Audio Experience

| Feature | Why it matters | Complexity | Key API / technical consideration | Score |
|---|---|---|---|---|
| **Repeating Ready Alert Sound** (#2) | If the first chime is missed while holding in `READY_WAITING`, a repeat interval keeps the break visible without spamming. | Low–Medium | Scheduler ticker (`C_Timer.NewTicker` on modern; OnUpdate accumulator on 3.3.5a). Use `PlaySound` / `PlaySoundFile` with a sensible channel. Stop on state change, combat, death, disable, or max repeats. | ★★★★☆ |
| **Soft Dimming / Vignette Mode** (#4) | A 95% blackout can feel harsh. A 70% vignette or soft dim is gentler, more immersive, and better for photosensitivity/accessibility. | Medium | Fullscreen overlay at high strata; support solid vs vignette styles. Wrap gradient APIs: legacy `SetGradientAlpha` vs modern `SetGradient` with color objects. Prefer a custom edge BLP/TGA vignette for consistency. Decide whether the overlay blocks mouse input or remains non-interactive. | ★★★★☆ |
| **Accessibility Visual/Audio Options** *(new)* | High-contrast text, reduced motion, no flashing, and quiet mode make the addon usable for more players and reduce break fatigue. | Low–Medium | Settings toggles for overlay style/alpha, warning flash off, sound category selection, and font scale. Test at multiple UI scales and resolutions. Avoid strobing effects; respect existing overlay cancel behavior. | ★★★★☆ |

## Tier 3 — MMO Ergonomics & Holistic Wellness

| Feature | Why it matters | Complexity | Key API / technical consideration | Score |
|---|---|---|---|---|
| **Tradeskill / Batch Crafting Detection** (#5) | Long crafting queues are exactly when players forget to blink. A “TAKE BREAK NOW” prompt is useful, but false positives would be annoying. | Medium–High | `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_STOP`, `UNIT_SPELLCAST_SUCCEEDED`; parse `UnitCastingInfo` / `UnitChannelInfo` defensively; correlate with `TradeSkillFrame:IsShown()` or crafting UI visibility. Track repeated casts over a time window rather than a single cast. Never auto-blackout during combat. Guard `GetSpellInfo` vs `C_Spell.GetSpellInfo`. | ★★★☆☆ |
| **Hourly Health & Hydration Reminders** (#6) | Extends the addon from eye rest to hydration, standing, and posture checks—high value for long sessions. | Low–Medium | Independent epoch timer using `time()` / `GetServerTime`, not just uptime. Persist last reminder. Queue reminder if combat or blackout active. Use a small toast plus optional sound; avoid stacking with eye-break prompts. | ★★★★☆ |
| **Post-Break Micro-Exercise Routine** (#7) | The eye break ends, but the body is still sedentary. A short neck/shoulder/wrist cue after the break turns a timer into a wellness habit. | Low–Medium | Add a `POST_BREAK` state after `RESTING`; show a non-modal guidance panel with skip/dismiss; auto-hide after 10–20s. No special APIs; keep it optional and non-blocking. | ★★★★☆ |

## Tier 4 — Advanced Addon Ecosystem & Power User Features

| Feature | Why it matters | Complexity | Key API / technical consideration | Score |
|---|---|---|---|---|
| **Gamification & Compliance Streaks** (#8) | Streaks and badges improve long-term adherence, but poorly done gamification can feel nagging. | Medium | Store daily aggregates in SavedVariables; compute daily/weekly streaks from epoch or server-day boundaries. Use `date` / `time` carefully and avoid timezone drift. Badges should be derived, not manually stored where possible. | ★★★☆☆ |
| **LDB / TitanPanel / ChocolateBar / ElvUI Support** (#9) | Standard bar integration gives power users fast access and makes the addon feel native in custom UIs. | Medium | Embed `LibDataBroker-1.1`; create a `type = "launcher"` data object with `OnClick` and `OnTooltipShow`. Optional ElvUI datatext adapter if needed. No hard dependency; degrade gracefully if LibStub/LDB is absent. | ★★★★☆ |
| **Per-Character & Activity Profiles** (#10) | Players behave differently while raiding, leveling, or crafting. Profiles let them switch cadence and strictness without reconfiguring. | High | Versioned SavedVariables schema: `profiles`, `activeProfile`, per-character mapping, migration path, copy/defaults/import. Must avoid data loss and keep combat/AFK/death gates consistent across profiles. | ★★★★☆ |
| **Slash Command / Macro API + Settings Import-Export** *(new)* | Power users want quick toggles and backups; support/debugging becomes easier. | Low–Medium | `SlashCmdList` / `hash_SlashCmdList`; serialize settings safely; validate imported data; never execute insecure strings. Useful commands: lock, pause, snooze, profile switch, export. | ★★★★☆ |

## Sprint Recommendation

Build these first:

1. **Death / Ghost Safety Gate** — safety-critical, low effort, immediately removes bad prompts and false stats.
2. **Pre-Break Countdown / Warning** — highest UX payoff for the least code; prevents surprise blackouts and combat friction.
3. **Mini-Widget Quick Lock / Tooltip Polish** — cheap, visible daily improvement that makes the addon feel finished.

If sprint capacity remains, add **Repeating Ready Alert Sound** next. Defer profiles and LDB until the core state transitions and safety gates are rock-solid.