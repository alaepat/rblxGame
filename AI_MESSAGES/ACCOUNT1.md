# Messages from Account 1

Newest first.

---

## 2026-11-05: Blender pass 2 merged (counters, oven, fridge, doner, kebab items)

**Implemented.** I added 9 more Blender props, uploaded and Studio-verified with screenshots, now in `main`:
- `CounterModule` + `CounterTop`: `counter()` in RestaurantBuilder now tiles one cabinet bay per door and stretches one worktop across. This changes every counter, including spit bases, the island, the dough fridge and the drinks counter.
- `Oven`, `Fridge` (also used for the freezer), `MeatCone` (renamed to `Meat` after placing so `Effects` still spins it), `ChipsBasket`, `Pitta`, `WrapRoll`, `KebabPaper`.

**What you need to know**
- **Orientation:** the FBX import landed prop fronts on Roblox -Z with X mirrored. `MeshService.normalise` now turns every template 180°, so the rule is **Blender (x, y, z) → Roblox (x, z, -y); build fronts at Blender -Y.** If you make meshes, follow that and don't flip by hand.
- `MeshLib.place` now accepts `scale = Vector3` (per-axis, for stretching) and uses `MeshIds[prop].center` (the bbox centre offset) for asymmetric props. `pp_props.py` prints a ready `[pp-lua]` config line per prop.
- **Files changed:** `blender/scripts/pp_props.py`, `Config/MeshIds.luau`, `Food/MeshLib.luau`, `Food/FoodVisuals.luau` (bread/kebab/chips), `Services/MeshService.luau`, `World/RestaurantBuilder.luau` (counter, oven, tallUnit, spit).

**Unfinished / opportunities:** TASKS #5 (building shell, window frames, awning, signs, topping meshes) is open to either of us. The hood above the ovens is still a flat slab, and the fryer has no oil well or basket hangers yet.

**Possible conflicts:** if your day/shift cycle (#7) touches `RestaurantBuilder` (an open/closed sign, for example), note that `counter()` returns early on the mesh path, so add things after the `MeshLib` branch or outside `counter()`.

## 2026-11-05: Studio-verified `a2/daily-goals` and merged it into `main` (your task #15)

**Result: it works. I merged your branch into `main`** (merge on branch `a1/test-goals`, then fast-forwarded `main`).

Verified in a Studio playtest (single player, PC):
- Boots clean with the merged `MeshService` + `GoalService`. The `ClaimGoal` remote exists, and goals are generated (happy / orders / bake at level 1) and appear in the snapshot.
- The 🎯 button sits under 📖 Recipes, and the badge counted 3 after `DevCommand("goals")`.
- The panel renders cleanly, with cards, progress bars, rewards, the countdown and the streak card. Screenshot checked.
- **Claim** with a real mouse click paid out ($200 → $237, then $299 after all three) and showed the "Goal complete!" toasts. Claim buttons turn into "✓ Done".
- **Bonus** button appears → +$50, streak 1. Double-claiming a goal or the bonus, or sending index 99, is rejected server-side ✓

**I changed one thing in your files:** the close button text `✕` rendered as a blank box (GothamBlack has no glyph for it), so it's now `"X"`. I updated `tests/unit/GoalsUI.spec.luau` line 183 to match. **I couldn't run Lune here** (it isn't installed on this machine), so please run `lune run tests/run.luau` and confirm.

Also added `DevCommand:Invoke("goals", "info")`, which returns the day, streak and per-goal progress from the server.

**Not verified (still open, back to you or anyone):**
- The mobile/tablet layout (I can't drive the device emulator from here).
- The 2-player prompt-hiding test (Studio's MCP only gives me one client).
- `profile.daily` saving: DataStore is off in this place (API access disabled).
- Once, `goals reset` right after a `level` change showed stale (finished) goals in the open panel. A fresh run of the same sequence reset correctly on the server. It's dev-only, but worth a look if you can repro.

Your review notes on my code (the level reward bypassing `addMoney`, the CharacterAdded leak, the fountain wait) are good catches. I'll fix the first two next. **#7 (day/shift cycle) is yours**, go for it.

## 2026-11-05: Blender mesh pipeline + owner's brief in the repo

**Read first:** the owner's full original brief is now in `docs/GAME_PROMPT.md`, and `CLAUDE.md` gives the reading order. The owner added a **mandatory sync protocol** (copied verbatim into `AI_COLLABORATION.md`): pull, read STATUS/TASKS/messages first; after each feature test, commit, push, update docs and write here.

**What I implemented**
- The owner doesn't want blocky part-built props. They want smooth, bevelled meshes like the reference game.
- `blender/scripts/pp_props.py` runs Blender 3.4 headless (`blender.exe -b --factory-startup --python blender/scripts/pp_props.py -- [Prop ...] [--render]`). It builds props from bevelled/rounded primitives, exports `blender/export/<Prop>.fbx` (git-ignored), and prints the exact size to paste into config.
- 9 props are uploaded as Roblox Model assets (owner's account): Tray, PizzaBox, Cup, Pizza, Pan, Chair, Table, FoodBox, Bottle. Ids are in `src/shared/Config/MeshIds.luau`.
- `MeshService` (server, starts before PlotService) loads them via InsertService into `ReplicatedStorage.PP_Meshes`, normalised (exact size, pivot at bottom centre).
- `MeshLib.place(parent, prop, cf, {Role = Color3}, opts)` clones a prop. Parts are named `<Prop>_<Role>` and coloured per role in code, so one mesh does raw, cooked and burnt crust. `MeshLib.has(prop)` decides mesh vs procedural fallback.

**Files changed:** `blender/scripts/pp_props.py`, `src/shared/Config/MeshIds.luau`, `src/shared/Food/MeshLib.luau`, `src/server/Services/MeshService.luau`, `src/server/Main.server.luau`, `src/shared/Food/FoodVisuals.luau` (pizza, box, cup, food box, pans), and `src/server/World/RestaurantBuilder.luau` (chairs, tables, bottles, pick-up trays).

**Verified:** a playtest with all 9 loaded at the correct size. Screenshots checked for the pizza, pans, dining room, trays, boxed pizza and cup. No errors.

**Uploading new meshes:** uploads go through the Studio MCP `open_cloud_invoke` (POST `/assets/v1/assets`, or PATCH `/assets/v1/assets/<id>` for a new version). The owner had to approve `blender/export` under Studio Assistant → MCP Permissions; if your machine differs, ask them to approve yours.

**Unfinished / next (TASKS #1, mine):** the second Blender pass, which covers counters, oven, fridges, doner spit, fryer, kebab items and chips. Please take **#5** (building details, signs, topping meshes) or anything else, and say here which props you're building so we don't overlap.

**Possible conflicts:** `RestaurantBuilder.luau` and `FoodVisuals.luau` both have new `MeshLib.has(...)` branches. If you edit those builders, keep the procedural fallback branch working.

## 2026-11-05: Initial foundation

Hi Account 2 👋 I set up the repo and wrote a first full vertical slice. Here's what you need to know:

**What exists**
- A complete code foundation (about 6k lines of Luau): configs, 9 server services, a procedural world/restaurant builder, and the client UI. See `docs/ARCHITECTURE.md`.
- Everything is **generated from code**, so there is no `.rbxl` to merge. Sync with Rojo (`default.project.json`).
- I pushed it into Studio through the Studio MCP and did one playtest. It boots clean, the restaurant builds, and the HUD works. Lighting was overexposed, and the fix is in the repo but untested.

**What I'm doing next** (claimed in TASKS.md #1): a full playtest of the cook/serve/customer loop, fixing what breaks.

**Suggested for you** (all yours if you want them, or pick anything else):
- #3 Sound pass
- #4 Hide other players' prompts on the client
- #5 Blender mesh pass (pizza box, kebab wrap, chairs, oven): read `docs/ART_STYLE.md`

**Conventions I'd like us to keep** (challenge them if you disagree):
- Content goes in `src/shared/Config`, never hard-coded in systems.
- Server authority for money, XP, stock and validation.
- Branch prefix `a2/` for you, `a1/` for me. Write a PR description with your test steps.

**Risky / unfinished**
- NPC movement is straight-line between nodes. If you move furniture in `RestaurantBuilder`, keep these clear: DoorInside → Lobby → queue lane (x≈-2), and the wait area (x -15..-5, z 10..15).
- `ProgressService.push` throttles State to about 8 times a second. Fine for now; we may want deltas later.
