# Messages from Account 1

Newest first.

---

## 2026-11-06: Mesh loading is parallel (#22 done)

`MeshService.start` now spawns every `LoadAsset` at once (one retry each) and waits for the last, with a 45 s cap. Studio: 54 meshes in 3.1 s (was about 25 s). It still blocks until done, so builders can keep calling `MeshLib.has` as before. A `[MeshService] N meshes ready in Xs` line prints at boot.

## 2026-11-06: Booths and wall art are meshes

`booth()` now places two `BoothBench` meshes facing each other plus a `BoothTable` (same footprint as before, so seating_2 is unchanged). The wall art is an `ArtFrame` with a poster Part (a label on its +Z face), one per dining side wall. Studio-verified with seating_1 + seating_2 bought. TASKS #5 is now an optional small-kit pass and is unclaimed if you want it.

## 2026-11-06: Signs are Blender meshes now

New meshes `SignEdge`, `PlanetSign`, `PylonPost` and `BladeSign` (ids in `MeshIds`). If you add a sign or a screen, call `edgeFrame(ctx, x1, y1, x2, y2, z, color)` in RestaurantBuilder for the rounded cabinet edge; `screen()` already does it. `meshBar()` stretches any 1-stud bar prop between two points. All fall back to the old parts when a mesh is missing. Studio-verified.

**Blender note:** `rot_apply()` in `pp_props.py` now rotates a mesh about its own bounding-box centre. Primitives created by the helpers often have their location baked in, so rotating about the object origin moved parts away (that bit the crater floors).

## 2026-11-06: The restaurant is wider too (81 x 66)

`GameConfig.SideExtra = 10`. In `RestaurantBuilder`: `XW`/`XE` are the side wall lines, `IW`/`IE` the inner faces. The kitchen builds west-wall kit on `kw` (ovens, dough fridge) and east-wall kit on `ke` (kebab station, spits, fryer) = offset contexts, so their old coordinates still read as before. The shell hood/chimney use `swk`. **The prep line, pass, drinks island, register and pickup did not move.** Upgrades, station names and nodes are unchanged (the customer spawn moved with the lawn). Studio-verified with every upgrade bought.

## 2026-11-06: The restaurant is bigger (please read if you touch the layout)

The owner said the inside felt too small next to the reference game, and asked for room for freezer storage and an office with the ordering PC. Done, Studio-verified, on `main`:
- **New constants:** `GameConfig.FrontExtra = 12` and `GameConfig.BackExtra = 10`. In `RestaurantBuilder`, `ZF = 22 + DF` is the front wall line and `ZB = -22 - DB` the back wall line. The storefront and back facade are built on offset contexts (`sf`, `sb` in `buildShell`; `of`, `ob` in `buildOutside`), so their old coordinates still read as z = 22 / -22.
- **The kitchen (z -8..6) did not move.** If you add something to the dining room, use z up to `ZF - 1`. Keep the door → lobby → queue walk clear (x 6..17, z 17..ZF).
- `WorldBuilder` moved the road, sidewalks, street lamps, houses, hub spawn and plot signs out by `FrontExtra`.
- Back rooms were rebuilt (`buildBack`): a walk-in freezer room holds the ❄️ Freezer station, the 🧊 Fridge is on the west wall facing into the room, and the office PC station is now labelled "💻 Owner PC (orders & upgrades)" with a tablet next to it. Station names and categories are unchanged.
- New meshes: `FrameBar`, `BarStool`, `Fryer` (ids in `MeshIds`).

**Possible conflicts:** if your staff NPCs (#11) walk to fixed positions, use the nodes (`DoorInside`, `Lobby`, `Queue*`, `Wait*`, `DeliveryPad`); they all moved with the layout. TASKS #23 has two gameplay ideas for the new rooms.

## 2026-11-06: All older props rebuilt at high quality

All 25 batch 1–3 props were rebuilt with `PP_QUALITY=2` and PATCHed as **new versions of the same asset ids**, so nothing in code changed except two sizes in `MeshIds` (Chair, and a tiny centre offset on PizzaBox). The dining **Chair** and **Table** are redesigned (bistro chair with stretchers and foot caps; four-star pedestal table). Roles are unchanged (`Shell/Legs`, `Top/Edge/Base`). Studio-verified with a dining-room screenshot.

Still procedural, and either of us can take them: the bar stools, the fryer body, window frames and signs (TASKS #5). Startup mesh loading is still serial (TASKS #22).

## 2026-11-06: High-poly food + building props are in `main`

The owner asked for "high poly, ultra realistic" props, not generic blocky ones. Done in this pass (Studio-verified with screenshots):
- **`pp_props.py` quality system:** `PP_QUALITY` (default 2) scales every primitive's segment count, and parts are decimated to stay under 19k triangles. New organic helpers: `displace` (noise), `lumpy`, `tube` (curve), `outline` (2D extrude, triangulated caps).
- **Food:** Pizza v2 (puffy crust, bubbly cheese, re-uploaded as a new version, same id) + 17 `Top_*` topping meshes + `Dough`. `FoodVisuals.scatter` now places a mesh per ingredient (`TOPPING_MESH` map at the top of the file, with role colours derived from `ing.color`). **If you add an ingredient**, either map it to an existing `Top_*` mesh there or it falls back to the procedural parts.
- **Building:** Awning, DoorLeaf, WallLamp, Hood, Parasol, Bench, Planter in `RestaurantBuilder`; StreetLamp in `WorldBuilder`. Every one keeps its procedural fallback under `if MeshLib.has(...)`.
- **`MeshLib.role` changed:** it now uses the text after the last underscore. Old props are unaffected (no underscores in their names).

**Files:** `blender/scripts/pp_props.py`, `Config/MeshIds.luau`, `Food/MeshLib.luau`, `Food/FoodVisuals.luau` (scatter, dough, pizza topping height; the flat "Brown" spot discs are gone on the mesh path), `World/RestaurantBuilder.luau`, `World/WorldBuilder.luau`.

**Not done / for either of us:** startup is slow because MeshService loads 44 assets one after another (about 25 s in Studio), see TASKS #22. The older batch-1/2 props haven't been rebuilt at high quality yet (TASKS #5, mine). I couldn't run Lune here; pure logic is unchanged, but please run the tests when you pull. Your PR #3 is still waiting for its Studio check (#20).

## 2026-11-06: Fixed your three review notes on my code

All Studio-verified, on `main`:
1. **Level-up cash** now goes through `ProgressService.addMoney(player, reward, "level")`, so it's rounded and counted in `stats.earned`. Verified: level 1 → 3 gave earned = $225.
2. **CharacterAdded leak:** `PlotService.claim` stores the connection on `plot.charConn`, and `release()` disconnects it. Verified that respawn still lands on the plot spawn.
3. **Fountain:** the pour delay now runs in `task.delay`, so the prompt handler returns immediately. `refresh()` shows a disabled "Pouring..." while `st.busy`, so other refreshes can't re-enable it mid-pour. If the cup is dropped or binned mid-pour, the syrup is refunded. Verified: normal pour → "Planet Cola", and binning mid-pour → stock refunded.

**Files:** `ProgressService.luau`, `PlotService.luau`, `StationService.luau` (Fountain action + refresh branch). Nothing of yours touched. Pure logic is unchanged, so your Lune specs shouldn't be affected, but please run them when you next pull.

## 2026-11-06: Studio-verified your day/shift cycle (PR #2) and merged it into `main`

**It works, nice job.** Checked in Studio (PC, single player):
- The clock pill shows "DAY 1 · CLOSED" with the rush timeline and doesn't overlap the HUD. OPEN starts at 10:00 AM, and the clock runs at 40 s per game hour (measured).
- `("day", 12)` gives the "🔥 Lunch rush! Customers are pouring in." toast, an orange phase label and the now-marker. Customers arrive faster.
- I served a real order during the rush and the pill updated to orders + earnings.
- `("day","close")` flips the sign to CLOSED with a "Last customers 0:12" countdown, then the **summary card** appears. The stats were right (sales $8 + tips $3.22 = my $11.22), with grade D (2 walk-outs), rating 4.00 → 3.20 and the shift bonus +$5.40 +4 XP. The button closes the card, and the clock moved to Day 2.

**Two fixes I made while merging (please keep them):**
1. **Leftover customers after the day ended:** customers still queueing when the grace period ran out stayed in the restaurant and walked out angry *after* the summary, dropping the rating (3.2 → 2.8) for something the player couldn't prevent. I added `CustomerService.sendHomeAll(plot)` (no review, bubble says "👋 See you tomorrow!"), called at the top of `ShiftService.finish`. Re-tested: 2 queued customers left, and the rating stayed at 4.0.
2. **Plural:** the pill now says "1 order" (`DayClock.luau` line ~78). `DayClockUI.spec` only checks "3 orders", so it should still pass. **I couldn't run Lune here**, so please run the tests.

**Not verified:** the phone emulator layout, `profile.shift` saving (DataStore is off in this place), and how the dinner rush (×2) feels at level 1. My scripted cook was slow, so two lunch-rush customers walked out; a real player at level 1 might struggle too. Worth tuning `DayCycle` rush multipliers by level (TASKS #18).

Take #16 or #3, whichever you prefer. I'm going to fix your two review notes on my code next (the level reward bypassing `addMoney`, and the CharacterAdded leak).

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
