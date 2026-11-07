# Tasks

Claim a task by putting your account in **Owner** and committing. Move finished tasks to **Done** with the date.

## Open

| # | Task | Area | Owner | Notes |
|---|---|---|---|---|
| 3 | Sound pass: fill `SoundIds.luau` with licensed / free Creator Store audio | Polish | **Account 2 (suggested)** | Keep ids in config only |
| 27 | Remaining mastery checks: phone emulator layout of the recipe-card row, `profile.mastery` saving with DataStore on | QA | — | PC verified 2026-11-07 |
| 11 | Staff NPCs (cashier, cleaner) as late-game upgrades | Gameplay | **Account 2** | Wages are ready: return hired staff from `ShiftService.staffOf` and the day summary charges `Config/DayCycle.Wages` (PR #2) |
| 14 | Published-place DataStore test (session lock, save on leave, BindToClose) | Data | — | Needs the owner to publish the place |
| 15 | Remaining daily-goals checks: mobile emulator layout, 2-player prompt hiding, `profile.daily` saving with DataStore on | QA | — | PC panel, claim, bonus and server validation verified + merged into main 2026-11-05 (Account 1) |
| 17 | Daily goals extras: one free reroll per day, a weekly challenge, a "GoalDone" sound | Progression | — | Config in `Challenges.luau` |
| 18 | Remaining day-cycle checks: phone-emulator layout of the clock pill + summary card, `profile.shift` saving with DataStore on, whether the dinner rush (×2) is too much at low levels | QA | — | PC flow Studio-verified + merged 2026-11-06 by Account 1. Rush scaling by level (PR #4) merged 2026-11-07 |
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
| #5 Blender pass 10: StandMixer (kitchen side counter), office Monitor + Keyboard/mouse (OS label kept on a thin screen panel), staff Locker ×5, glass-front Vending ×2 (cola + snacks, products behind glass, keypad), chrome WireShelf for every storage/freezer/upgrade shelving unit (stretched per unit) (Studio-verified) | Account 1 | 2026-11-07 |
| #12 Mobile/tablet UI pass: `Client/UI/Responsive` scales every ScreenGui (Root frame + UIScale, desktop stays 1), PC/POS windows fill the screen when scaled, finger-sized prompt rows on touch, `Responsive.spec`; previewed at 844×390 with `workspace:SetAttribute("PP_EmulateScreen", …)` (Studio-verified; a real device / Studio device-emulator check is still open in #15, #18, #27) | Account 1 | 2026-11-07 |
| #13 Interior themes: office PC "🎨 Decor" tab, 5 dining themes (Classic free; Retro Diner 4 $600, Tuscan Trattoria 7 $1,000, Space Station 10 $1,600, Gold & Marble 14 $3,000) restyling floor, panels, walls, tables, chairs, booth/stool seats incl. the annex; `Config/Themes` + `ThemeService`, saved as `profile.theme(s)` (Studio-verified) | Account 1 | 2026-11-07 |
| #10 done: garlic bread (garlic butter tub on each prep board, level 17) and calzones (Fold prompt F on the prep board, level 18; Blender Calzone mesh) (Studio-verified) | Account 1 | 2026-11-07 |
| Dessert Station (upgrade, level 12): soft-serve machine + topping jars, 5 sundaes, new `dessert` item kind; Blender SoftServe + SundaeCup (Studio-verified) | Account 1 | 2026-11-07 |
| Levels 13–20 content: 6 pizzas (Galaxy Pizza = 12 toppings), 5 kebab-station dishes (Planet Mega Box), Hotter Oven III, Bigger Storage III, Premium Packaging; board caps derived from recipes; paging menu boards (Studio-verified) | Account 1 | 2026-11-07 |
| #6 Carry pose (arms forward while holding anything) + customer idles in the queue/waiting area (look around, check phone, shift weight); client `Controllers/Poses` (Studio-verified) | Account 1 | 2026-11-07 |
| #9 3D recipe previews (on-screen cards only); Blender `Carton` for deliveries + shelf stock (Studio-verified) | Account 1 | 2026-11-07 |
| #23 Office tablet = "Quick restock" (suggested top-up cart, `Shared/Food/Restock` + spec); new "Freezer Racks" upgrade (x2 frozen capacity, extra rack in the walk-in) (Studio-verified) | Account 1 | 2026-11-07 |
| #25 Day-clock pill hides under the OS/POS windows; #26 Recipes tab refreshes mastery live (Studio-verified) | Account 1 | 2026-11-07 |
| #2 Extension annex fixed (blocked opening, floating poster/neon, nested upgrade visibility) and PizzaBox v2 checked (Studio-verified) | Account 1 | 2026-11-07 |
| PR #4 rush tuning Studio-verified (multipliers measured live) and merged; level-up popup merges chained level-ups and auto-closes; `DevCommand("traffic")` | Account 1 | 2026-11-07 |
| #20 Studio-verified menu mastery (PR #3) on PC and merged into `main` (remaining checks #27) | Account 1 | 2026-11-07 |
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
