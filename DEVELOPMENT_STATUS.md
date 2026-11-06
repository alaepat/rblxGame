# Development Status

_Last updated: 2026-11-06 by Account 2 (daily goals, day cycle and menu mastery sections; the rest is Account 1's)_

## Verified in a Studio playtest (2026-11-05, synced via Rojo)
- The server and client boot with no script errors. The town and restaurant generate (about 1,070 parts, 32 active stations at level 1).
- **Full pizza loop**: dough bin → board → tomato sauce → mozzarella (→ tomato) → pick up → oven (cook %, READY, then BURNT if left) → take out → box → serve. All work, and the bin throws away a burnt pizza.
- **Customers**: the OPEN sign spawns customers, who walk in and queue ("Ready to order"). The register opens the POS. A wrong order is rejected, the correct one becomes Order #1, both items are served at pick-up, and the customer pays ($17 plus a $3.53 tip) and leaves. XP is awarded.
- **Supplies**: ordering validates level locks and storage capacity. The delivery arrives at the back-door pallet after 12 s, and boxes are carried into the fridge and dry storage.
- **Upgrades**: the level lock is enforced server-side.
- The HUD and menu boards work. Lighting is no longer overexposed.
- In a published place without Studio API access, DataStore now fails fast to a temporary profile (no 30 s retry delay).

### Second pass (same day, using the `ServerStorage.DevCommand` test hooks)
- Upgrades: bought 10 at level 8. Every upgrade model appeared and every placeholder was removed (kebab station, fryer, oven 2, prep 2, seating, heat shelf slots, plants, neon, pendants, storage).
- **Kebab**: pitta → board → chicken doner spit → lettuce, tomato, garlic sauce → Wrap → "Wrapped Chicken Doner Kebab" ✓
- **Loaded fries**: frozen chips → fryer → hot chips → heat shelf → food box on board → Add chips → cheddar, chicken doner, garlic → Close → "Loaded Fries" ✓
- **Drinks**: cup → fountain pours after 1.5 s → "Planet Cola" ✓ (fixed: hold prompts never completed with the custom interaction UI; all prompts are now single-press)
- **Cleaning**: spawned rubbish and a spill, cleaned both, cleanliness 84% → 100% ✓
- **Level-up popup** (unlock list) ✓ and **office PC** (Pizza Planet OS) ✓
- Fixed: newer emoji (🫓🫑🫒🪴🪧) rendered as blank boxes in Roblox, so they're replaced.
- Added interior plaster cladding (back rooms, above the kitchen tiles, dining walls) so no brick shows inside. Not visually re-checked yet.

## Added by Account 2 (2026-11-05): daily goals, merged into main; PC panel, claim, bonus and validation Studio-verified by Account 1
- **Daily goals + streaks** (the brief asks for XP and money from challenges): 3 goals per player per UTC day from 10 templates (orders, earnings, pizzas, drinks, happy customers, perfect bakes, cleaning, tips, a specific recipe, kebabs). Goals are gated by level and upgrades, and targets and rewards scale with level. Claim each goal for cash + XP. Claiming all three unlocks a streak bonus (×1.25 per consecutive day, capped at ×2.5). Rewards that were finished but never claimed are paid automatically at the next reset. Saved in `profile.daily`.
- **Goals panel**: a 🎯 Goals button under 📖 Recipes with a red badge counting claimable rewards. It opens a cream card panel with progress bars, Claim buttons, the streak/bonus card and a countdown to new goals.
- **Own-plot prompts only** (task #4): the Interaction controller skips prompts inside another player's `Restaurant_*` model.
- **Offline tests**: `lune run tests/run.luau` gives 24 passing tests: every src file compiles, DailyGoals rules, GoalService against fake services (claim validation, payouts, rollover), and the goals panel built with real Lune Instances. `rojo build` succeeds.
- Studio hooks: `DevCommand:Invoke("goals")` finishes every goal, `DevCommand:Invoke("goals", "reset")` rerolls.
- **Still to check** (TASKS #15): the mobile/tablet layout, the 2-player prompt-hiding test, and `profile.daily` saving with DataStore on.

## Day / shift cycle (Account 2, 2026-11-06): merged into `main`, PC Studio-verified by Account 1
- Verified: clock pill (DAY N / CLOSED, no overlap), OPEN starts 10:00 AM at 40 s per game hour, lunch-rush toast + orange phase, the order + earnings counter, closing time flips the sign and shows a "Last customers" countdown, the summary card (stats, grade, rating change, shift bonus; the money adds up), the card dismisses and the clock rolls to Day 2.
- Fixed in the merge: customers still inside when the day ended stayed and walked out angry after the summary, costing rating. `CustomerService.sendHomeAll` now sends them home with no review (called from `ShiftService.finish`). The pill also says "1 order" instead of "1 orders".
- Each restaurant runs its own day. Opening the sign starts **Day N at 10:00**; 1 game hour = 40 s, so 10:00–22:00 is an 8-minute day.
- Phases from `Config/DayCycle.luau`: morning, 🔥 lunch rush 12–14 (×1.8 customers), afternoon lull, 🔥 dinner rush 17:30–20 (×2), evening, 🌙 late-night rush 21–22 (×1.4). Toast + bell when a rush starts.
- At 22:00 the sign closes itself. When the last customers leave (or after 90 s), the **end-of-day summary card** shows orders, food counts, sales, tips, happy %, walk-outs, rush orders, rating change and a grade (S–D), pays a **shift bonus** (×1.5 for a full day) and charges **staff wages** (0 until staff exist, #11). Days played and best day are saved in `profile.shift`.
- **Day clock pill** top-left above the order list, with a timeline bar showing the rushes and a "now" marker.
- Closing early ends the day too; reopening before 22:00 continues it. A day only counts once an order was served.
- Studio hooks: `DevCommand:Invoke("day", 12)` jumps the clock, `("day", "close")` goes to closing time, `("day", "end")` ends the day now.
- Offline: 56 Lune tests pass (pure rules, ShiftService against fakes, the clock/summary UI with real Lune Instances); `rojo build` OK. Studio checklist is in PR #2 (TASKS #18).

### Blender meshes (2026-11-05)
- `blender/scripts/pp_props.py` builds 9 smooth props headless in Blender 3.4 (Tray, PizzaBox, Cup, Pizza, Pan, Chair, Table, FoodBox, Bottle) → FBX → uploaded as Roblox Model assets (ids in `Config/MeshIds.luau`, all moderation-approved).
- In a playtest, MeshService loaded all 9 at the exact config size with the pivot at bottom centre. Verified visually: pizza (rolled crust, organic sauce/cheese), steel topping pans, dining chairs + tables, pick-up trays, boxed pizza, cup with lid and straw. No errors.
- PizzaBox v2 uploaded (the logo ring was standing upright; now flat). The re-upload isn't re-checked in game yet.
- **Pass 2 (Studio-verified 2026-11-05):** CounterModule + CounterTop (every kitchen counter is now tiled bevelled cabinet bays + a stretched worktop), dome Oven with arched brick mouth, glass-door Fridge/Freezer, layered MeatCone (still spins), ChipsBasket, Pitta, WrapRoll, KebabPaper. Screenshots checked for the ovens, kebab station, fridges, heat-shelf food and dining.
- **Orientation fix:** the FBX import put prop fronts on -Z (X mirrored). MeshService now turns every template 180°, so Blender (x, y, z) -> Roblox (x, z, -y) and fronts face +Z. This also fixed dining chairs, which had been facing away from their tables.
- **Pass 3 + 4 (Studio-verified 2026-11-06, Account 1):** high-poly food and building props.
  - `pp_props.py` has a quality factor (`PP_QUALITY`, default 2 = high-poly) applied to every primitive, plus organic helpers (noise `displace`, `lumpy`, curve `tube`, `outline`) and a 19k-triangle cap per part.
  - **Pizza v2** (puffy cornicione, bubbly cheese) and **18 new food meshes**: one `Top_*` mesh per topping (cupped pepperoni with fat flecks, tomato slices with gel + seeds, mushroom slices, olive/onion rings, ham, pepper strips, grilled chicken, beef crumble, cheddar/cabbage shreds, lettuce, doner strips, chips, sauce drizzle, cheese) and a floured **Dough** ball.
  - `FoodVisuals.scatter` maps each ingredient to its `Top_*` mesh (`TOPPING_MESH`), with random yaw, tilt and ±10% size, and derives every role colour from the ingredient colour. Procedural parts remain the fallback.
  - Building props are wired in: storefront Awning (11 curved bays), DoorLeaf ×2, WallLamp ×4 (lights on the glow part), kitchen Hood over the ovens, patio Parasols, Bench, Planters and StreetLamps (arm over the road on both curbs).
  - `MeshLib.role` now takes the text after the **last** underscore, so prop names may contain underscores (`Top_Pepperoni_Fat` → `Fat`).
  - Verified with screenshots: storefront, three topped pizzas and the dough, the hood over the ovens. All 44 meshes load (about 25 s at server start in Studio).
- **High-quality rebuild (2026-11-06, Account 1):** the 25 older props were rebuilt at `PP_QUALITY=2` and re-uploaded as new versions (same ids). The dining **Chair** (dished seat, curved tapered back, splayed tapered legs, sub-frame, stretchers, foot caps) and **Table** (eased laminate top, four-star cast base with levelling pads) were redesigned. Screenshot of the dining room checked.
- Still procedural: fryer body, the building shell walls, window frames, signs, bar stools.

### Also verified (2026-11-05, third pass)
- An angry walk-out drops the rating gently (4.0 → 3.5, fixed from 1.0). Counter wiping restores cleanliness. Emergency delivery sends 4 boxes and then goes on cooldown.

## Menu mastery (Account 2, 2026-11-06): branch `a2/menu-mastery`, PR #3, offline-tested, NOT Studio-verified
- Every served recipe counts toward its mastery: 🥉 Bronze 10 · 🥈 Silver 30 · 🥇 Gold 75 serves (drinks ×2). Each tier pays a one-off reward scaled to the recipe (price ×3/×6/×12, XP ×2/×4/×8) and adds +10/20/30% bonus XP to every later serve of that recipe. Numbers in `Config/Mastery.luau`.
- Recipes tab cards show stars, a progress bar and "12 / 30 to 🥈 Silver"; the Business tab shows "Menu mastery ★ N / 75". Saved as serve counts in `profile.mastery`.
- Studio hook: `DevCommand:Invoke("mastery", "cheese_pizza")` jumps a recipe to its next tier.
- Offline: 75 Lune tests pass; `rojo build` OK. Studio checklist in PR #3 (TASKS #20).

## Not yet verified end-to-end
- The extension annex (level 10)
- Real DataStore saving (enable **Game Settings → Security → Enable Studio Access to API Services**, then rejoin)

## Known issues / gaps
- Roblox only shows a prompt when its part is on screen, so players must look at what they interact with (that's intended).
- Stainless steel (Metal material) looks quite dark in enclosed rooms. Consider a lighter colour or SmoothPlastic for counter bodies.
- `Lighting.Technology` must be set to **Future** by hand (scripts can't set it).
- No sound ids yet: `SoundIds.luau` is all empty, so the game is silent.
- ~~Other players can see prompts in your restaurant~~: fixed and merged into `main` (the 2-player check is still open, TASKS #15).
- NPCs walk straight lines between nodes (no pathfinding), so layout changes must keep the paths clear.
- 44 Blender meshes are in. The building walls, window frames and signs are still procedural (TASKS #5). MeshService loads meshes one by one, so the server takes about 25 s to build in Studio; loading them in parallel would speed that up.
- No staff or delivery orders yet (see TASKS.md). The day/shift cycle is merged; menu mastery is on `a2/menu-mastery` (PR #3), waiting for a Studio check.

## Phase progress (from the master prompt)
| Phase | State |
|---|---|
| 1 Environment | Procedural restaurant, town, lighting done; visual polish ongoing |
| 2 Interactions | Done (needs playtest) |
| 3 Food | Pizza + kebab + drinks + chips done (needs playtest) |
| 4 Customers | Done (needs playtest) |
| 5 Progression | XP / levels / unlocks / money done; daily goals + streaks merged (PC Studio-verified); day/shift cycle merged (PC Studio-verified); menu mastery on `a2/menu-mastery` (PR #3, offline-tested) |
| 6 Expansion | Upgrades, stock, deliveries, extension annex done |
| 7 UI | HUD, POS, manager, level-up, toasts done |
| 8 Multiplayer & saving | Per-player plots + DataStore done; needs a published-place test |
| 9 Polish | Not started (sound, animations, VFX, optimisation) |
