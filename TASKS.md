# Tasks

Claim a task by putting your account in **Owner** and committing. Move finished tasks to **Done** with the date.

## Open

| # | Task | Area | Owner | Notes |
|---|---|---|---|---|
| 1 | Playtest angry walk-outs, counter wiping, emergency delivery, extension annex; visual check of new interior walls | QA | Account 1 | Use ServerStorage.DevCommand (see DevService.luau) |
| 2 | Tune light balance; make stainless counters read lighter (Metal looks dark indoors) | Visual | — | See DEVELOPMENT_STATUS known issues |
| 3 | Sound pass: fill `SoundIds.luau` with licensed / free Creator Store audio | Polish | **Account 2 (suggested)** | Keep ids in config only |
| 5 | Blender pass: pizza box (open lid), kebab wrap, chair, pizza oven dome as MeshParts + `MeshIds.luau` with procedural fallback | Art | **Account 2 (suggested)** | See docs/ART_STYLE.md |
| 6 | Player hold/serve animations (arms forward when carrying), customer eating/idle variety | Animation | — | |
| 7 | Day/shift cycle (lunch/dinner rush, closing time, end-of-day summary + wages) | Gameplay | — | Inspired-by feature; design first in AI_MESSAGES |
| 9 | Recipe book: show a mini 3D preview (ViewportFrame) of each recipe | UI | — | FoodVisuals.build can render into a ViewportFrame |
| 10 | More content past level 12: desserts, garlic bread, calzone, sides | Content | — | Config-driven |
| 11 | Staff NPCs (cashier, cleaner) as late-game upgrades | Gameplay | — | |
| 12 | Mobile/tablet UI pass (scale HUD, bigger touch targets) | UI | — | Test with the Studio device emulator |
| 13 | Interior themes / decorations shop (restyle floors, tables, wall colours) | Expansion | — | |
| 14 | Published-place DataStore test (session lock, save on leave, BindToClose) | Data | — | Needs the owner to publish the place |
| 15 | Studio-verify `a2/daily-goals`: goals panel (PC + mobile emulator), Claim/bonus, toasts, `profile.daily` saving, other players' prompts hidden (2-player test) | QA | — | `DevCommand:Invoke("goals")` finishes all goals. Merge into `main` once it looks right |
| 16 | Menu mastery: per-recipe serve counts → bronze/silver/gold stars with small cash/XP bonuses (reference "Progress" tab) | Progression | — | Can reuse the `serve_recipe` event from GoalService |
| 17 | Daily goals extras: one free reroll per day, a weekly challenge, a "GoalDone" sound | Progression | — | Config in `Challenges.luau` |

## Done
| Task | By | Date |
|---|---|---|
| Repo structure, Rojo project, docs | Account 1 | 2026-11-05 |
| Config: ingredients, recipes (pizza/kebab/drinks), upgrades, levels | Account 1 | 2026-11-05 |
| Services: data, progress, held items, stations, customers, supply, cleaning, upgrades, plots | Account 1 | 2026-11-05 |
| Procedural town + restaurant (kitchen, ovens, prep lines, kebab station, front counter, dining, storage, office, staff room, extension) | Account 1 | 2026-11-05 |
| Client: HUD, aim-to-interact, POS, Pizza Planet OS manager, toasts, level-up popup | Account 1 | 2026-11-05 |
| #8 Daily goals / challenges with XP + cash rewards, streak bonus, goals panel (branch `a2/daily-goals`, offline-tested; Studio check is #15) | Account 2 | 2026-11-05 |
| #4 Hide other players' prompts on the client (branch `a2/daily-goals`) | Account 2 | 2026-11-05 |
| Lune offline test harness (`tests/`, 24 tests) | Account 2 | 2026-11-05 |
