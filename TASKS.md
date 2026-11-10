# Tasks

Claim a task by putting your account in **Owner** and committing. Move finished tasks to **Done** with the date.

## Open

| # | Task | Area | Owner | Notes |
|---|---|---|---|---|
| 3 | Sound pass: fill `SoundIds.luau` with licensed / free Creator Store audio | Polish | **Account 2 (suggested)** | Keep ids in config only |
| 14 | Published-place DataStore test (session lock, save on leave, BindToClose), including that `profile.mastery`, `profile.daily` (rerolls, weekly), `profile.shift`, `profile.theme(s)` and `profile.masteryDay` survive a rejoin | Data | — | Needs the published group place "Pizza p" with Studio API access on |
| 32 | Whether the dinner rush feels too busy at levels 1-3 (play a real day at level 1-3) | QA | — | Rush is already scaled by level (PR #4); cook edge cases done 2026-11-10 |

## Done
| Task | By | Date |
|---|---|---|
| #32 part: cook edge cases in Studio (Pizza p): two cooks take two ovens at once and both box + shelve; full heat shelf: cook holds the boxed pizza ("Heat shelf is full!") until a slot frees, then shelves it; no pizza boxes: owner toast "Cook: out of pizza boxes!" and the pizza goes on the shelf unboxed. New dev hooks `oven`, `shelf`, `boxes` | Account 1 | 2026-11-10 |
| #31 Two-player check (local server, 2 players, Pizza p, run by the owner): own restaurants, other player's prompts hidden, own day/night sky (Player1 at night while Player2 stays day), own before-you-open card, own money | Owner (checklist by Account 1) | 2026-11-10 |
| #29 done: more than one of a role. New upgrades Second Cleaner (level 15, $1,800) and Second Pizza Cook (level 17, $3,500); StaffService runs a crew per role (`staff.crew`, first NPC still `staff.npcs[role]`), claims stop two NPCs taking the same mess or oven, extra hires stand 3 studs aside, wages count per hire; one cashier (one register) (Studio-verified: 5 NPCs, two cleaners cleaning two messes at once, fire removes all; two cooks at once not seen live) | Account 1 | 2026-11-10 |
| #29 part: staff poses. `Poses` now also poses `Staff_<role>` NPCs: carry pose while the cook holds a pizza, wipe / type / box work poses from a new `Activity` model attribute (set in `StaffService.say` from the status line), idles (look around, shift weight, folded arms) while waiting (Studio-verified for cashier + cleaner; cook carry/box not seen live) | Account 1 | 2026-11-10 |
| Phone-layout QA (rest of #15, #18, #27, #30) at 844×390: clock pill, day summary card incl. the 4-column items row with desserts, recipe-card mastery row, goals panel (scrolls). Fixed: level-up popup could stack on the day summary (Notifications looked for `DaySummary` as a direct child, but Responsive moves it into `Root`), and the before-you-open checklist now hides while the summary is up | Account 1 | 2026-11-10 |
| #28 + #30 Studio check of staff (PR #5), desserts (PR #6) and Pizza Cook (PR #7) in the group place "Pizza p": cashier takes orders, cleaner cleans, cook watches/boxes/shelves, dessert column + $80 wages on the summary | Owner (with Account 2) | 2026-11-09 |
| #29 part: Pizza Cook staff upgrade (level 13, $2,200, $35/day): takes pizzas out of the oven when ready, boxes them, puts them on the heat shelf (branch `a2/cook`, PR #7, stacked on PR #5; 130 tests; Studio check is #30) | Account 2 | 2026-11-09 |
| #29 part: desserts counted in the day stats + summary column, "Serve N desserts" daily goal (branch `a2/dessert-stats`, PR #6; Studio check is #30) | Account 2 | 2026-11-09 |
| #11 Staff NPCs: cashier + cleaner as Staff upgrades, wages on the day summary (branch `a2/staff`, PR #5, offline-tested with 121 tests; Studio check is #28) | Account 2 | 2026-11-09 |
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
| #21 Mastery extras: "🏅 Mastery" tab in the office PC (every unlocked recipe at a glance, best first), gold recipes sell for +10% (`Tiers[].priceBonus`, `Mastery.priceFor`, used for order prices, register and recipe book), daily goal "Serve N different recipes" (`serve_variety` from MasteryService); `MasteryExtras.spec` (Studio-verified; a live gold-priced customer order not yet checked) | Account 1 | 2026-11-08 |
| #19 Day-cycle extras: "Before you open" checklist card while closed (stock for the unlocked menu, cleanliness, empty ovens/fryers; "Heads up" toasts if you open anyway), rush daily/weekly goal ("Serve N orders during a rush hour", `rush_order` event from ShiftService), client day/night lighting that follows the shift clock; `Shared/Shift/Checklist`, `Shared/Shift/Sky`, `Controllers/DayExtras`, `DayExtras.spec` (Studio-verified) | Account 1 | 2026-11-07 |
| #17 Daily goals extras: one free "🎲 Swap" per day on an unfinished goal (RerollGoal remote), a weekly challenge (Monday reset, 7× target, 5× reward, auto-paid if unclaimed, ClaimGoal("weekly")), `GoalDone` sound id, scrolling goals list on small screens; `GoalExtras.spec` (Studio-verified; DailyGoals + GoalExtras specs run green in Studio) | Account 1 | 2026-11-07 |
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
