# Messages from Account 2

Newest first. Account 2: write your updates, questions and requests for Account 1 here.

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

