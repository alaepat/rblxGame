# Tasks

Claim a task by putting your account in **Owner** and committing. Move finished tasks to **Done** with the date.

## Open

| # | Task | Area | Owner | Notes |
|---|---|---|---|---|
| 2 | Re-check PizzaBox v2 in game (ring now flat); playtest extension annex (level 10) | QA | — | |
| 3 | Sound pass: fill `SoundIds.luau` with licensed / free Creator Store audio | Polish | **Account 2 (suggested)** | Keep ids in config only |
| 5 | Blender pass 10 (optional): stand mixer, PC monitor, lockers/vending, storage shelving | Art | — | Fronts face +Z after import. Pass, rails and office desk/chair are done. |
| 23 | Use the new space: decide whether the office tablet should be its own station (stock-only shortcut) and whether the walk-in freezer should hold more frozen stock (capacity upgrade) | Gameplay | — | Layout in `RestaurantBuilder.buildBack`; the tablet is decor next to the Owner PC station today |
| 6 | Player hold/serve animations (arms forward when carrying), customer eating/idle variety | Animation | — | |
| 9 | Recipe book: show a mini 3D preview (ViewportFrame) of each recipe | UI | — | FoodVisuals.build can render into a ViewportFrame |
| 10 | More content past level 12: desserts, garlic bread, calzone, sides | Content | — | Config-driven |
| 11 | Staff NPCs (cashier, cleaner) as late-game upgrades | Gameplay | **Account 2** | Wages are ready: return hired staff from `ShiftService.staffOf` and the day summary charges `Config/DayCycle.Wages` (PR #2) |
| 12 | Mobile/tablet UI pass (scale HUD, bigger touch targets) | UI | — | Test with the Studio device emulator |
| 13 | Interior themes / decorations shop (restyle floors, tables, wall colours) | Expansion | — | |
| 14 | Published-place DataStore test (session lock, save on leave, BindToClose) | Data | — | Needs the owner to publish the place |
| 15 | Remaining daily-goals checks: mobile emulator layout, 2-player prompt hiding, `profile.daily` saving with DataStore on | QA | — | PC panel, claim, bonus and server validation verified + merged into main 2026-11-05 (Account 1) |
| 17 | Daily goals extras: one free reroll per day, a weekly challenge, a "GoalDone" sound | Progression | — | Config in `Challenges.luau` |
| 18 | Remaining day-cycle checks: phone-emulator layout of the clock pill + summary card, `profile.shift` saving with DataStore on, whether the dinner rush (×2) is too much at low levels | QA | — | PC flow Studio-verified + merged 2026-11-06 by Account 1. **Account 2** is scaling rushes by level (branch `a2/rush-tuning`) |
| 20 | Studio-verify `a2/menu-mastery` (PR #3): recipe-card stars/progress row (PC + phone emulator), tier toasts + payouts, Business tab card, `profile.mastery` saving. Merge into `main` if it looks right | QA | — | Checklist in PR #3. `DevCommand:Invoke("mastery", "cheese_pizza")` |
| 21 | Mastery extras: a mastery tab in the office PC with all recipes at a glance, a "master 3 recipes" daily goal, a small price bonus on gold recipes | Progression | — | Builds on #16. Counts are in the snapshot as `mastery` |
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
| #16 Menu mastery: bronze/silver/gold per recipe, tier rewards, serve XP bonus, Recipes/Business tab UI (branch `a2/menu-mastery`, PR #3, offline-tested with 75 tests; Studio check is #20) | Account 2 | 2026-11-06 |
| #24 Level-up popup waits for the day-summary card (Studio-verified) | Account 1 | 2026-11-07 |
| Full-shift playtest; fixed zero-stock unlocks (free starter box per newly unlocked ingredient) and the "1 orders" HUD text; `DevCommand("queue")` test hook | Account 1 | 2026-11-07 |
| Pass, rails, office: HeatGantry, PrepRail x3, OfficeDesk, OfficeChair (Studio-verified with screenshots) | Account 1 | 2026-11-06 |
| Small kit: SodaFountain, CupDispenser, TrashBin, TableCaddy, POS stand/bezel/printer (Studio-verified) | Account 1 | 2026-11-06 |
| #22 Parallel mesh loading in MeshService (54 meshes in 3.1 s, was ~25 s) | Account 1 | 2026-11-06 |
| Booths (BoothBench x2 + BoothTable) and framed wall posters (ArtFrame) (Studio-verified) | Account 1 | 2026-11-06 |
| Signs: SignEdge cabinet edges (roof, entrance, pylon, all screens), sculpted PlanetSign, PylonPost, new BladeSign (Studio-verified) | Account 1 | 2026-11-06 |
| Wider building (81 x 66): kitchen kit moves with the side walls, 11 base tables, more booths/windows (Studio-verified) | Account 1 | 2026-11-06 |
| Bigger building (66 deep: dining 26, back rooms 23.5) with a walk-in freezer room and a larger owner's office; FrameBar, BarStool and Fryer meshes (Studio-verified) | Account 1 | 2026-11-06 |
| Blender pass 3 + 4: high-poly Pizza v2, 17 topping meshes + Dough wired into FoodVisuals; Awning, DoorLeaf, Hood, WallLamp, StreetLamp, Planter, Parasol, Bench wired into the builders (Studio-verified) | Account 1 | 2026-11-06 |
| #7 Day/shift cycle: rushes, closing time, end-of-day summary, shift bonus, wages hook (merged into `main`; PC Studio-verified by Account 1; remaining checks #18) | Account 2 | 2026-11-06 |
