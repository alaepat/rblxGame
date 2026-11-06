# Tasks

Claim a task by putting your account in **Owner** and committing. Move finished tasks to **Done** with the date.

## Open

| # | Task | Area | Owner | Notes |
|---|---|---|---|---|
| 2 | Re-check PizzaBox v2 in game (ring now flat); playtest extension annex (level 10) | QA | — | |
| 3 | Sound pass: fill `SoundIds.luau` with licensed / free Creator Store audio | Polish | **Account 2 (suggested)** | Keep ids in config only |
| 5 | Blender pass 3: WIRE IN the 8 uploaded building props (Awning, DoorLeaf, Hood, WallLamp, StreetLamp, Planter, Parasol, Bench; ids already in MeshIds) in RestaurantBuilder (lines ~290 doors, ~320 awning, ~351 wall lamps, ~407 hood, ~1098 parasols, ~1105 bench, ~1110 planters) and WorldBuilder (~123 street lamps); then window frames, signs, toppings | Art | Account 1 | Fronts face +Z after import. Awning/StreetLamp/WallLamp have a bbox centre offset |
| 6 | Player hold/serve animations (arms forward when carrying), customer eating/idle variety | Animation | — | |
| 9 | Recipe book: show a mini 3D preview (ViewportFrame) of each recipe | UI | — | FoodVisuals.build can render into a ViewportFrame |
| 10 | More content past level 12: desserts, garlic bread, calzone, sides | Content | — | Config-driven |
| 11 | Staff NPCs (cashier, cleaner) as late-game upgrades | Gameplay | — | Wages are ready: return hired staff from `ShiftService.staffOf` and the day summary charges `Config/DayCycle.Wages` (PR #2) |
| 12 | Mobile/tablet UI pass (scale HUD, bigger touch targets) | UI | — | Test with the Studio device emulator |
| 13 | Interior themes / decorations shop (restyle floors, tables, wall colours) | Expansion | — | |
| 14 | Published-place DataStore test (session lock, save on leave, BindToClose) | Data | — | Needs the owner to publish the place |
| 15 | Remaining daily-goals checks: mobile emulator layout, 2-player prompt hiding, `profile.daily` saving with DataStore on | QA | — | PC panel, claim, bonus and server validation verified + merged into main 2026-11-05 (Account 1) |
| 16 | Menu mastery: per-recipe serve counts → bronze/silver/gold stars with small cash/XP bonuses (reference "Progress" tab) | Progression | — | Can reuse the `serve_recipe` event from GoalService |
| 17 | Daily goals extras: one free reroll per day, a weekly challenge, a "GoalDone" sound | Progression | — | Config in `Challenges.luau` |
| 18 | Remaining day-cycle checks: phone-emulator layout of the clock pill + summary card, `profile.shift` saving with DataStore on, whether the dinner rush (×2) is too much at low levels | QA | — | PC flow Studio-verified + merged 2026-11-06 by Account 1 |
| 19 | Day-cycle extras: a "Before you open" checklist (stock, clean, oven on), daily goals tied to rushes ("serve 5 orders in the lunch rush"), day/night lighting that follows the clock | Gameplay | — | Builds on #7. Rush orders are already counted in `DayCycle.record` |

## Done
| Task | By | Date |
|---|---|---|
| Repo structure, Rojo project, docs | Account 1 | 2026-11-05 |
| Config: ingredients, recipes (pizza/kebab/drinks), upgrades, levels | Account 1 | 2026-11-05 |
| Services: data, progress, held items, stations, customers, supply, cleaning, upgrades, plots | Account 1 | 2026-11-05 |
| Procedural town + restaurant (kitchen, ovens, prep lines, kebab station, front counter, dining, storage, office, staff room, extension) | Account 1 | 2026-11-05 |
| Client: HUD, aim-to-interact, POS, Pizza Planet OS manager, toasts, level-up popup | Account 1 | 2026-11-05 |
| #8 Daily goals / challenges with XP + cash rewards, streak bonus, goals panel (PC Studio-verified and merged into `main` by Account 1; remaining checks are #15) | Account 2 | 2026-11-05 |
| #4 Hide other players' prompts on the client (merged into `main`; 2-player check in #15) | Account 2 | 2026-11-05 |
| Blender pass 2: counters, oven, fridge, meat cone, fryer basket, pitta, wrap, kebab paper (+ mesh orientation fix) | Account 1 | 2026-11-05 |
| Lune offline test harness (`tests/`, 24 tests) | Account 2 | 2026-11-05 |
| #7 Day/shift cycle: rushes, closing time, end-of-day summary, shift bonus, wages hook (merged into `main`; PC Studio-verified by Account 1; remaining checks #18) | Account 2 | 2026-11-06 |
