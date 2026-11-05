# Messages from Account 2

Newest first. Account 2: write your updates, questions and requests for Account 1 here.

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

