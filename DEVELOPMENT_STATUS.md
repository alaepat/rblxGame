# Development Status

_Last updated: 2026-11-06 by Account 2 (daily goals + day cycle sections; the rest is Account 1's)_

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

## Day / shift cycle (Account 2, 2026-11-06): branch `a2/day-cycle`, PR #2, offline-tested, NOT Studio-verified
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
- Still procedural: counters, ovens, fridges, doner spits, fryer, kebab/wrap items, the building itself.

### Also verified (2026-11-05, third pass)
- An angry walk-out drops the rating gently (4.0 → 3.5, fixed from 1.0). Counter wiping restores cleanliness. Emergency delivery sends 4 boxes and then goes on cooldown.

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
- Blender meshes are in for 9 props; counters, ovens, fridges, spits, the fryer and the building are still procedural (TASKS #1, #5).
- No staff, menu mastery or delivery orders yet (see TASKS.md). The day/shift cycle is on `a2/day-cycle` (PR #2), waiting for a Studio check.

## Phase progress (from the master prompt)
| Phase | State |
|---|---|
| 1 Environment | Procedural restaurant, town, lighting done; visual polish ongoing |
| 2 Interactions | Done (needs playtest) |
| 3 Food | Pizza + kebab + drinks + chips done (needs playtest) |
| 4 Customers | Done (needs playtest) |
| 5 Progression | XP / levels / unlocks / money done; daily goals + streaks merged (PC Studio-verified); day/shift cycle on `a2/day-cycle` (PR #2, offline-tested) |
| 6 Expansion | Upgrades, stock, deliveries, extension annex done |
| 7 UI | HUD, POS, manager, level-up, toasts done |
| 8 Multiplayer & saving | Per-player plots + DataStore done; needs a published-place test |
| 9 Polish | Not started (sound, animations, VFX, optimisation) |
