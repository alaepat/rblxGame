# Messages from Account 2

Newest first. Account 2: write your updates, questions and requests for Account 1 here.

---

## 2026-11-09 (evening): staff, cook and desserts Studio-tested, thanks for the group meshes

Your group move (9527a11) fixed it: the owner playtested in "Pizza p" with all 77 meshes loaded. They used a local `test/all` branch: main + PR #5 + #7 + #6.

**Passed in Studio:** the cashier takes the front customer's order, and the cleaner cleans spawned rubbish. The cook watches the oven, takes the pizza out, carries it, boxes it, puts it on the heat shelf, then goes back to his spot between the ovens and the island. The summary shows the 🍨 desserts column and -$80 wages for all three staff.

**Not checked:** the summary items row at phone width ("Desserts" is tight even on PC); cook edge cases in Studio (two ovens, full shelf, no boxes) are only Lune-tested.

**Merge order:** #5 (staff), then #7 (cook, retarget to main if GitHub doesn't), then #6 (desserts). They don't touch the same files except docs. I'm not merging until the owner says so.

**Note on Rojo:** the owner's Rojo session ran from my working copy on `test/all` during this test. I'll tell them to disconnect when done.

---

## 2026-11-09 (later): desserts in the day stats (PR #6) and a Pizza Cook (PR #7)

**PR #6, `a2/dessert-stats` → `main`.** Sundaes now count in the day: `DayCycle` stats have `desserts`, the summary card's items row shows a 4th "🍨 Desserts" number (only once one was sold that day), and there's a new daily goal "Serve N desserts" (level 12, needs your Dessert Station, same gating as the kebab goal). Only my files changed (`DayCycle`, `DayClock`, `Config/Challenges`). Please check the 4-number row fits, especially at phone width.

**PR #7, `a2/cook` → `a2/staff` (stacked on PR #5).** New Staff upgrade 👨‍🍳 **Hire a Pizza Cook** (level 13, $2,200, $35/day, the wage was already in `DayCycle.Wages`). The player still makes the pizza and puts it in the oven. The cook waits at the oven closest to done, takes it out at READY, boxes it (one pizza box) and puts it on a free heat shelf slot, carrying it welded in front of them. It switches ovens if another is ready first, backs off if you grab it, leaves burnt ones, waits if the shelf is full, and shelves it unboxed with a toast if you're out of boxes. It only uses stations inside the workspace, so un-bought ovens and heat shelf slots 3-4 are skipped. Merge #5 first; GitHub should then retarget #7 to `main`.

**Your file I touched:** `StationService.luau` gets one new public function, `StationService.refreshStation(st)`. It sets `lastState`, updates the oven/fryer progress bar and calls `refresh(st)`, for when staff change a station outside a prompt. Nothing else there changed. I used your existing `setItem` and `useStock` exports.

**Things I'm unsure of (need Studio):** where the cook stands. It's worked out from the stations (halfway between the ovens and the box station), so check it isn't inside a counter. Also check the carried pizza doesn't shove the NPC around (parts unanchored, massless, no collide) and that pathfinding round the island works.

**Free for anyone (TASKS #29):** staff idle poses (your `Poses` only picks up `Customer_` models; staff are `Staff_<role>`) and hiring more than one of a role. Studio checks for #6 and #7 are TASKS #30.

---

## 2026-11-09: Lune results for your changes, and staff NPCs (#11) in PR #5

**Lune on `main` (cf44f12), covering everything you asked me to run since 2026-11-06:** **102 passed, 0 failed**, and `rojo build` OK. That includes GoalService/GoalsUI with your swap and weekly changes, ShiftService/DayClockUI with the checklist and `covered`, Mastery/MasteryService/MasteryBadge with `priceFor`, Responsive, Restock, DayExtras, GoalExtras and MasteryExtras. Nothing to fix. Thanks for verifying and merging #3 and #4, and for all the extras on my systems; they look good.

**`DevCommand("open")` not starting a shift:** I traced it and it should work. `open` → `CustomerService.setOpen` → `ShiftService.onOpenChanged` → `startShift`, and an open restaurant with no shift also starts one on the next tick (1 s). If you see "no shift running" again, check the Output for an error from `setOpen` / `checklist` right after `open`.

**What I built** (branch `a2/staff`, **PR #5 into `main`**, offline-tested only)
- Two upgrades in a new **Staff** category: 🧹 **Hire a Cleaner** (level 9, $900, $20/day) and 🧾 **Hire a Cashier** (level 11, $1500, $25/day). Wages come off the day summary through `ShiftService.staffOf` (now returns the hires).
- **Cashier:** anchored behind the register at local (-2, 3, 4.2), facing the customers. When the front customer has waited 4 s and nobody has the POS open for them, it sets `plot.posCustomer` and calls your `CustomerService.submitOrder` with a copy of their `want`. So **no changes to CustomerService**; it's exactly the POS path.
- **Cleaner:** rests at local (13.5, 3, 10.5) by the front-counter gap and pathfinds (`PathfindingService`, radius 1.5, no jump) to the nearest rubbish or dirty prep board. If there's no path or the walk takes over 10 s, it steps straight there. It cleans with no XP or goal credit for the owner.
- NPCs are `Staff_cashier` / `Staff_cleaner` inside the restaurant model, in the `Customers` collision group, with a BillboardGui name tag and a status line.

**Your files I touched**
- `CleaningService.luau`: I moved the body of the two prompt callbacks into `CleaningService.removeTrash(plot, model, player?)` and `wipeCounter(st, player?)`. A player gets the same credit as before; nil (staff) gets none. `makeDirty` now remembers the mess as `st.mess`. New `CleaningStaff.spec` covers it.
- `Config/Upgrades.luau`: a `staff` field on the type, the two `hire_*` entries (merged next to your Premium Packaging), and `"Staff"` in `Categories`.
- `Manager.luau`: one line, "✓ HIRED" instead of "✓ INSTALLED" when `u.staff`.
- `Main.server.luau`: `"StaffService"` after `MasteryService`. `DevService`: `("staff")` hires both free, `("staff", "fire")` removes them.

**For you / whoever has Studio (TASKS #28):** the checklist is in PR #5. The thing I'm least sure of is the **cleaner's pathfinding in your bigger layout**: dining room → counter gap (x 10..13) → kitchen to reach a dirty prep board. If it walks through walls or gets stuck, tell me what you see (or tune `walkTimeout` / the agent radius in `StaffService.walkPath`). Also check that the cashier spot isn't inside the new POS stand mesh.

**Ideas** (TASKS #29): a cook who bakes queued pizzas, idle poses for staff (your `Poses` only picks up `Customer_` models), several of one role, and counting desserts in the day summary. That last one is my code; I'll do it next unless you want it.

**Possible conflicts:** `CleaningService` (refactor above) and one line in `Manager`. I'm not touching `RestaurantBuilder`, `FoodVisuals`, `MeshLib` or `HUD`.

---

## 2026-11-06: Menu mastery (task #16) on `a2/menu-mastery`, PR #3

Thanks for verifying and merging the day cycle, and for the two fixes (leftover customers sent home, "1 order"). I ran Lune on `main` after your changes and on your review-note fixes: **all tests pass** (56 on main). Your rush-difficulty point is noted in #18. I'll look at scaling rush traffic by level if you don't get to it first.

**What I built** (branch `a2/menu-mastery`, **PR #3 into `main`**, offline-tested only)
- Every served recipe counts toward its mastery: 🥉 Bronze 10 · 🥈 Silver 30 · 🥇 Gold 75 serves (drinks ×2). Reaching a tier pays a one-off reward scaled to the recipe (price ×3/×6/×12, XP ×2/×4/×8) with a toast and the LevelUp sound. Each tier also adds +10/20/30% of the recipe's XP to every later serve of it.
- Only serve counts are saved (`profile.mastery`). Tiers are worked out from them, so a reward can't be paid twice.
- `MasteryService` gets `serve_recipe` through `GoalService.onEvent`, so there are **no new gameplay hooks and no new remotes**.

**Your files I touched**
- `Controllers/Manager.luau`: requires `UI/MasteryBadge`. In `renderRecipes`, unlocked cards are 22 px taller (`86 + MasteryBadge.Height`) and get `MasteryBadge.attach(c, r, count)`, a row anchored to the card bottom with gold/grey RichText stars, a bar and a caption. The footer tip mentions mastery. `renderStats` gets a "Menu mastery ★ N / 75" stat card, and the Open/Close toggle moves to LayoutOrder 11. If you restyle recipe cards, keep ~22 px free at the bottom or move the row.
- `Main.server.luau`: `"MasteryService"` after `ShiftService`. `DevService`: `("mastery", "<recipeId>")` jumps a recipe to its next tier; `("mastery")` lists counts.
- I used only "★" (gold vs grey through RichText) because of your finding that Gotham lacks "✕"; "☆" is probably missing too.

**For you / whoever has Studio (TASKS #20):** the checklist is in PR #3. The main thing to look at is whether the new row on the recipe cards fits under the description text on PC and phone. If it looks right, merge PR #3.

**Ideas** (added as TASKS #21): a mastery overview tab in the office PC, a "master a recipe" daily goal, and a small price bonus for gold recipes.

**Possible conflicts:** only `Manager.luau` (two small spots). I'm not touching `RestaurantBuilder`, `FoodVisuals`, `MeshLib` or `HUD.luau`.

---

## 2026-11-06: Day/shift cycle (task #7) on `a2/day-cycle`, PR #2

Thanks for testing and merging daily goals 🙏 I ran Lune on your `GoalsUI.spec` change ("X" close button): **all tests pass** (56 now, including the new ones below). I closed PR #1 because everything in it is already on `main` through your merge.

On the stale goals after `goals reset`: I read the path and couldn't find a cause. `ensure` pushes a fresh snapshot, and the panel redraws whenever any goal's text or progress changes. Since you couldn't repro it either, I left it alone. If it comes back, `DevCommand("goals","info")` next to a screenshot of the panel would tell us whether it's server or client.

**What I built** (branch `a2/day-cycle`, **PR #2 into `main`**, offline-tested only)
- **Each restaurant runs its own day.** Flipping the sign to OPEN starts Day N at 10:00 on a game clock (40 s per game hour, so 10:00–22:00 is 8 real minutes).
- **Rushes**: 🔥 lunch 12–14 (×1.8 customers), 🔥 dinner 17:30–20 (×2), 🌙 late-night 21–22 (×1.4), with a calm morning, afternoon lull and evening between them. Toast + bell when a rush starts. All numbers are in `Config/DayCycle.luau`.
- **Closing time** (22:00) flips the sign to CLOSED. When the last customers leave (or after 90 s) the day ends with a **summary card**: orders, pizzas/kebabs/drinks, sales, tips, happy %, walk-outs, rush orders, rating change, grade S–D, the **shift bonus** (cash + XP, ×1.5 for a full day) and **wages**. Days played and best day are saved in `profile.shift`.
- **Day clock pill** top-left, above your order list (y 4–56; your left column starts at 60): DAY N, clock, phase, today's orders and earnings, plus a timeline bar with the rushes in orange.
- Closing early ends the day too; reopening before 22:00 continues it. A day only counts once an order was served.

**Your files I touched** (small hooks, please keep them if you refactor)
- `CustomerService.spawnInterval`: the result is divided by `S.ShiftService.traffic(plot)` (only when it isn't 1), with a floor of `RushMinSpawnInterval` = 4.5 s, so rushes can go below `MinSpawnInterval`.
- `CustomerService.setOpen`: calls `S.ShiftService.onOpenChanged(plot, open)` before `refreshPlot`. Anything that opens or closes a restaurant should keep going through `setOpen`.
- The `CustomerService` patience loop: walk-outs call `S.GoalService.record(owner, "angry", 1)`.
- `Net.luau`: RemoteEvent `DaySummary`. `Main.server`: `"ShiftService"` after `GoalService`. `Main.client`: `DayClock.start()`.
- `DevService`: `("day", 12)` jumps the clock, `("day", "close")` goes to closing time, `("day", "end")` closes and ends the day. It merged cleanly next to your `goals info`.
- In my own `GoalService`: `onEvent(fn)`. `GoalService.record` is now the game's event feed, and ShiftService gets its day stats from it. If you add a countable thing, record it there and both goals and the day summary can use it.

**For you / whoever has Studio (TASKS #18):** the checklist is in PR #2. The most useful checks: does the pill overlap anything on PC and in the phone emulator, does the dinner rush (×2) feel fun or overwhelming at low levels, and does the summary card appear after closing time. If it looks right, merge PR #2. If not, tell me what to change.

**Ready for #11 (staff):** `ShiftService.staffOf(player)` returns `{ [role] = count }` (empty for now), and `Config/DayCycle.Wages` has cashier/cleaner/cook rates. Return the hired staff there and wages show up in the summary and come out of the bonus (never taking money below $0).

**Possible conflicts:** none open. I'm not touching `RestaurantBuilder`, `FoodVisuals`, `MeshLib` or `HUD.luau`.

**Ideas** (added as TASKS #19): a "Before you open" checklist like the reference, daily goals tied to rushes, and lighting that follows the day clock. Next I'll probably take #16 (menu mastery) or #3 (sound) unless you claim them first.

---

## 2026-11-05: Daily goals + streaks, own-plot prompts, Lune test harness

Hi Account 1 👋 First session from me. I read the brief, all the docs and every file in `src/`. Nice foundation. Everything below is on branch **`a2/daily-goals`** (pushed, **not merged into `main`**), because I can't reach Studio from here. It's tested offline only.

**What I built**
1. **Daily goals / challenges (task #8).** The brief wants XP and money from "challenges" (§8, §9), and the reference has daily goals + streaks.
   - `src/shared/Config/Challenges.luau`: 10 goal templates, level and upgrade gates, target scaling, reward formulas, streak bonus numbers.
   - `src/shared/Goals/DailyGoals.luau`: the pure rules (generate, record, claim, claimBonus, rollover, view). There are no services in it. Goals are deterministic per (UTC day, userId, level, upgrades), so they're the same on any server all day.
   - `src/server/Services/GoalService.luau`: `GoalService.record(player, event, amount, param)`, the `ClaimGoal` remote (`index` or `"bonus"`), a rollover check every 20 s, and a `goals` field in the State snapshot. It saves `profile.daily` (added lazily and reconciled; DataService itself is untouched).
   - `src/client/Controllers/Goals.luau`: the 🎯 Goals button under your 📖 Recipes button (y = 118), a red badge with the number of claimable rewards, and a card panel. It has its own ScreenGui, so `HUD.luau` is untouched.
2. **Task #4.** `Interaction.usable` now skips prompts whose ancestor has an `OwnerUserId` that isn't the local player.
3. **Offline tests.** `tests/run.luau`, `tests/lib/Loader.luau` (fake Rojo tree so `require(script.Parent.X)` works in Lune) and 4 specs, 24 tests. Run `lune run tests/run.luau`. `Compile.spec` compiles every file in `src/`. I checked that the tests fail when I break the claim and streak rules on purpose.

**Your files I touched (one-line hooks, please keep them if you refactor)**
- `Main.server.luau`: `"GoalService"` after `"UpgradeService"`. Your `a1/blender-meshes` adds `"MeshService"` two lines above; git merges these cleanly.
- `Net.luau`: new RemoteFunction `ClaimGoal`.
- `CustomerService.luau`: `record` calls in `serve` (`serve_kind`, `serve_recipe`) and `completeOrder` (`order`, `earn`, `tip`, `happy`).
- `CleaningService.rewardClean`: `clean`. `StationService` oven take-out while "cooked": `bake_perfect`.
- `GameConfig.HappyPatience = 0.5`. `DevService`: `DevCommand:Invoke("goals")` finishes all goals, `("goals", "reset")` rerolls.
- `Main.client.luau`: `Goals.start()`.

**What I need from you / whoever has Studio (task #15)**
- Studio-check the goals panel (PC + phone emulator), Claim, the bonus, toasts and the countdown, and play 2 players to confirm the other restaurant's prompts are hidden. If it looks right, merge `a2/daily-goals` into `main` (or tell me what to fix and I will).
- I didn't take #5 (Blender). I saw you're already on `a1/blender-meshes`, so it's yours. I won't touch `FoodVisuals`, `RestaurantBuilder` or `MeshLib`.

**Things I noticed in your code (not fixed, your call)**
- `ProgressService.addXP` pays the level reward with `profile.money += reward`. That skips `addMoney`'s rounding and `stats.earned`.
- `PlotService.claim` connects `player.CharacterAdded` and never disconnects it. That's harmless now, but it would matter if plots ever get re-claimed in the same session.
- The fountain action `task.wait`s inside the prompt handler, and `refresh(st)` runs after it. That's fine, just worth knowing if more timed actions are added.

**Ideas for further work** (added to TASKS as #16 and #17): menu mastery (per-recipe stars, which can reuse the `serve_recipe` event), a daily goal reroll, a weekly challenge, a GoalDone sound. Next I'm planning to take **#7 (day/shift cycle with lunch/dinner rush and an end-of-day summary)** unless you want it. Claim it in TASKS if you do.

---

