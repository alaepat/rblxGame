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
- **Bigger building + batch 5 (Studio-verified 2026-11-06, Account 1):**
  - The restaurant is now 66 studs deep instead of 44. `GameConfig.FrontExtra = 12` pushes the storefront (and the street, sidewalks, lamps, houses and plot signs in `WorldBuilder`) out, and `GameConfig.BackExtra = 10` pushes the back wall out. The kitchen is unchanged.
  - **Dining** is 26 deep (was 14): 7 base tables (was 4), seating_1 adds 4, seating_2 adds 2 booths, plus a longer window bar with 5 stools. Customers still walk door → lobby → queue (verified: two NPCs reached Queue1/Queue2).
  - **Back rooms** are 23.5 deep: storage with dry shelving by the back door, the cold fridge on the west wall, and a **walk-in freezer room** (insulated panels, strip curtain, frost light, the freezer unit and a frozen rack). The **owner's office** has the PC desk with an "Order stock" tablet, a bookcase, filing, safe, rug and a meeting table. The staff room has lockers with a bench, a sofa, vending and a break table.
  - New Blender meshes: `FrameBar` (window frame profile, stretched along its length so the profile never distorts; 42 per restaurant), `BarStool`, `Fryer` (twin oil wells, splashback, dials, doors).
  - Screenshots checked: storefront, dining room, walk-in freezer, office, fryer.
- **Wider building (Studio-verified 2026-11-06, Account 1):** `GameConfig.SideExtra = 10` moves both side walls out, so the restaurant is 81 x 66 (was 61 x 44 this morning).
  - Kitchen: the ovens, hood, chimney and dough fridge moved with the west wall, and a new worktop run (mixer, flour sacks) fills the gap to the prep line. The kebab station, spits, fryer and chips freezer moved with the east wall. Prep line, pass and drinks are unchanged.
  - Dining: 11 base tables, seating_1 adds 7, seating_2 adds 3 window booths. Two more storefront windows, a longer awning, 5 wall lanterns, 7-wide ceiling light rows.
  - Back: bulk shelving in the wider storage room, a second vending machine and a second break table in the staff room. The annex, parking, lawn, pylon, bench and customer spawn moved out with the walls.
  - Verified with every upgrade bought: all stations in place (oven, kebab, fryer, fridge, hood), screenshots of dining and both kitchen ends, and customers walked from the sidewalk into the queue.
- **Signs (Studio-verified 2026-11-06, Account 1):** four new Blender meshes.
  - `SignEdge`: a rounded lightbox edge, stretched like `FrameBar`. `edgeFrame()` in RestaurantBuilder puts it around the roof sign (yellow), the ENTRANCE sign (red), both faces of the roadside sign (yellow) and every `screen()` (menu boards, promo board, kitchen order screens get a dark bezel).
  - `PlanetSign`: a cratered planet with a tilted ring (front edge up so it reads from the street) and a glowing band, replacing the ball + cylinder planet.
  - `PylonPost`: the roadside sign post with plinth, collar bands and cap.
  - `BladeSign`: a new wrought-iron bracket sign over the right-hand storefront window with a two-sided "🍕 PIZZA" disc, readable along the street.
  - `meshBar()` is the shared helper for any 1-stud bar prop stretched between two points (`frameBar` uses it too).
- **Booths + wall art (Studio-verified 2026-11-06, Account 1):** `BoothBench` (channel-tufted back, crowned cushion, piping, wood shell, cap rail, kick plate) placed in facing pairs around a `BoothTable` (rounded laminate top, chrome edge band, pedestal) by `booth()`. `ArtFrame` (moulded frame, gold lip, mat) holds a printed poster Part on each dining side wall ("SLICE OF THE GALAXY" east, "KEBAB ORBIT" west).
- **Counter + kitchen small kit (2026-11-06, Account 1):** `SodaFountain` (three valves with levers, slotted drip tray, red header; the flavour panels/labels and Fountain stations are unchanged and sit on its front face), `CupDispenser` (clear tube, the cup stack shows through), `TrashBin` (pedal bin), `TableCaddy` (napkin holder + salt & pepper on all 14 tables and booths), `PosStand` + `PosBezel` + `ReceiptPrinter` around the register screen.
  - Verified in Studio: all built, all four stations (RegisterHit, CupBin, Fountain_*, TrashHit) present, 61 meshes in 7.1 s, no errors. Screenshots of the register and a table caddy; the fountain was checked by measuring (panels flush on its front face, valves in front of each panel) because the Studio viewport went blank for the last captures.
- **Pass, rails and office (2026-11-06, Account 1):** `HeatGantry` (deck, chrome posts, hood with four heat-lamp bulbs) over the pass; `PrepRail` (rail housing, backsplash, bracketed shelf, LED strip, glass sneeze guard) on both pizza prep counters and the kebab counter; `OfficeDesk` (drawer pedestal) and a swivel `OfficeChair` in the owner's office. Pans, boards, heat-shelf slots and the PC station are unchanged; the old light parts are kept invisible as light sources.
  - Studio-verified: 65 meshes in 9.0 s, no errors, all stations present; screenshots checked of the prep line, the pass, the kebab counter and the office.
- Still procedural: the building shell walls (brick/plaster parts with materials), the mixer worktop.

### Also verified (2026-11-05, third pass)
- An angry walk-out drops the rating gently (4.0 → 3.5, fixed from 1.0). Counter wiping restores cleanliness. Emergency delivery sends 4 boxes and then goes on cooldown.

## Menu mastery (Account 2, 2026-11-06): PR #3, Studio-verified + merged into `main` by Account 1 on 2026-11-07
- Every served recipe counts toward its mastery: 🥉 Bronze 10 · 🥈 Silver 30 · 🥇 Gold 75 serves (drinks ×2). Each tier pays a one-off reward scaled to the recipe (price ×3/×6/×12, XP ×2/×4/×8) and adds +10/20/30% bonus XP to every later serve of that recipe. Numbers in `Config/Mastery.luau`.
- Recipes tab cards show stars, a progress bar and "12 / 30 to 🥈 Silver"; the Business tab shows "Menu mastery ★ N / 75". Saved as serve counts in `profile.mastery`.
- Studio hook: `DevCommand:Invoke("mastery", "cheese_pizza")` jumps a recipe to its next tier.
- Offline: 75 Lune tests pass; `rojo build` OK.
- **Studio (PC) verified 2026-11-07, Account 1:** no errors; Recipes cards show grey stars + "0 / 10 to 🥉 Bronze" (drinks "0 / 20"), locked cards unchanged, nothing overlaps the description; a real served Tomato Pizza + Orbit Orange counted (1 / 10, 1 / 20); `("mastery","cheese_pizza")` ×3 paid bronze (+$24, +20 XP toast) → silver → gold ("🥇 Mastered! +30% XP per serve", gold ★★★ RichText stars, no boxes), a 4th call says "already gold"; Business tab shows "Menu mastery ★ 3 / 75".
- Not verified: phone-emulator layout, `profile.mastery` saving (DataStore off in Studio). The open Recipes tab now refreshes live (#26).

## Tablet, Freezer Racks, 3D recipe previews, cartons (Account 1, 2026-11-07): Studio-verified
- **#23 Office tablet = "📱 Quick restock":** its own station; opens Supplies with a suggested top-up already in the cart (every unlocked ingredient under a third full, whole boxes up to capacity, emptiest first, max 12). Rule in `Shared/Food/Restock` + `Restock.spec`. Verified: 8 boxes suggested on a new restaurant, accepted by the server.
- **#23 Freezer Racks upgrade** (Storage, level 6, $350, needs Kebab Station): `capacity_frozen` +100% through a new per-category capacity effect (`capacity_<category>` in `ProgressService.capacity`), plus a stocked rack in the walk-in freezer. Verified: Chicken Doner 72 → 144, Frozen Chips 48 → 96, Mozzarella unchanged.
- **#9 3D recipe previews:** each recipe card shows the real food model (FoodVisuals) in a ViewportFrame: baked pizza, open kebab/wrap, filled cup; locked ones greyed. Models are cached; previews exist only for cards on screen (Roblox stops drawing ViewportFrames past a budget, which blanked the lower cards when all 25 were built). Verified with screenshots.
- **Cartons:** new Blender `Carton` (bulging corrugated sides, flap seam, packing tape, label). Used for the delivery boxes (label prints the ingredient + amount with a category-colour band; an invisible `Box` part keeps the pick-up prompt) and for shelf/freezer stock via `carton()` in RestaurantBuilder. Verified: pick-up still works, screenshots of pallet and shelves.
- **Packaging (2026-11-07):** pitta and pizza dough arrive in a blue plastic `BreadCrate` with the goods visible inside; wraps in a clear plastic `WrapBag` (transparent, sealed end, red label); everything else in the `Carton`. Packaging per ingredient is `CRATED` / `BAGGED` in `FoodVisuals.buildSupply`. Verified: all three on the pallet (screenshot), crate and bag pick up and store.
- **Poses (#6, 2026-11-07):** new client `Controllers/Poses` adds an offset to each joint's animated `.Transform` after the Animator runs (PreSimulation), so it works with both Motor6D rigs and the newer AnimationConstraint avatars. Players holding anything raise both arms forward under it; customers in the queue/waiting area (server sets model attribute `State`) look around, check a phone or shift weight every few seconds. Verified: hand moves from hip to chest height in front while carrying and back after; queued customers looked around.
- **Levels 13–20 content (2026-11-07):** 6 pizzas (Chicken & Mushroom 13, BBQ Meat Feast 14, Cheesy Inferno 15, Garden Supreme 16, Smokehouse 17, Galaxy Pizza 19 with all 12 toppings), 5 kebab-station dishes (Cheesy Chips 13, Chilli Chicken Wrap 14, Lamb Salad Box 15, Mixed Grill Pitta 18, Planet Mega Box 20), upgrades Premium Packaging (13), Hotter Oven III (15), Bigger Storage III (16), milestone notes. Board caps (`FoodLogic` max toppings/fillings) are now the biggest recipe of each kind instead of 8/9. Menu boards page through 10 items at a time every 6 s. Verified: 36 recipes at level 20, no duplicate ingredient sets, a real Galaxy Pizza cooked and recognised.
- **Dessert Station (2026-11-07):** upgrade `dessert_station` (Kitchen, level 12, $1,200) adds an island next to the drinks: Blender `SoftServe` machine (vanilla / chocolate levers, `SoftServe` stations with a pour delay), a dessert-cup stack (`Bin`), and 4 topping jars (`DessertTopping`: chocolate sauce, strawberry sauce, sprinkles, cookie crumble). New item kind `dessert` { flavour, toppings } in FoodLogic (canAddToDessert / identify / describe / isPackaged); 5 sundaes (levels 12–16) on the drinks board ("DRINKS & DESSERTS"); customers add a dessert to 30% of orders like drinks; recipe book steps + 3D preview via the `SundaeCup` mesh. Verified: cup → chocolate fill → 4 toppings → "Galaxy Sundae", screenshot. Not counted separately in the day summary (DayCycle counts pizzas/kebabs/drinks).
- **Garlic bread + calzones (#10 done, 2026-11-07):** garlic butter is a pizza "sauce" (tub beside each prep board, level 17): Garlic Bread (no toppings) and Cheesy Garlic Bread. Calzones: the prep board has a second prompt "Fold into a calzone" (F) from level 18 (`GameConfig.CalzoneLevel`) once the pizza has sauce + a topping; folded pizzas take no more toppings and only match recipes with `folded = true` (Classic Calzone 18, Meat Lover's Calzone 20). Blender `Calzone` mesh (crimped half-moon, steam slits) drawn by `FoodVisuals.buildPizza`. Verified: fold → "Raw calzone" → bake 19 s → "Boxed Classic Calzone"; garlic bread → "Boxed Garlic Bread"; adding a topping after folding is refused.
- Studio note: when the Studio window is behind other windows its 3D view (and ViewportFrames) renders white; bring it to the front before screenshots.

- **Blender pass 10 (#5, 2026-11-07):** 6 new meshes (batch 14 in `pp_props.py`, ids in MeshIds): `StandMixer` (Body/Bowl/Trim/Knob), `Monitor` (Bezel/Screen/Stand/Led; the "Pizza Planet OS" SurfaceGui stays on a thin `Monitor` part in the bezel), `Keyboard` (Case/Keys/Mouse), `Locker` (Body/Door/Vent/Handle/Plate/Kick), `Vending` (glass front, 5 trays of coils with cans `CanA` and bags `BagB`, keypad panel, header; game adds a `VendHeader` label part), `WireShelf` (Post/Wire/Foot; `shelving()` stretches it with `scale = (w/7.6, h/7, d/2.4)`, decks line up with the stacked stock). Procedural parts stay as the fallback. Verified: all load (77 meshes in ~10 s), staff room / office / kitchen / storage screenshots, upgrade shelving (Bigger Storage I+II, Freezer Racks) shows the mesh when bought.
- **Mobile / tablet UI (#12, 2026-11-07):** `Client/UI/Responsive.apply(gui, design)` moves a ScreenGui's children into a full-screen `Root` frame with a UIScale (scale = min(screen / design, 1), floor 0.55), so desktop-pixel layouts shrink evenly on small screens and desktop stays at 1. Design sizes: WINDOW 1000×470 (PC, POS), HUD 900×440 (HUD, Goals, DayClock), POPUP 900×560 (toasts, level-up). `Responsive.fit` makes the PC and POS windows 98% × 94% of the screen when scaled. Touch devices get 44 px prompt rows. The Manager footer tip uses the full bar on tabs without order buttons. Preview without the emulator: `workspace:SetAttribute("PP_EmulateScreen", Vector2.new(844, 390))` on the client. Verified at 844×390: HUD 0.89, PC 0.83 (Supplies, Recipes with 3D previews, tab clicks work), POS and the level-up window fit; desktop 1356×786 unchanged at scale 1. Not yet checked on a real phone or in the Studio device emulator.
- **Interior themes (#13, 2026-11-07):** office PC tab "🎨 Decor" (`Manager.renderDecor`) lists `Config/Themes` (classic, diner, trattoria, space, luxury) with colour swatches, level lock, Buy / Use buttons → remote `SetTheme` → `ThemeService.choose` (level check, `ProgressService.spend`, saves `profile.theme` + `profile.themes`). `ThemeService.apply(plot)` restyles parts by name inside the dining area (incl. the east annex and hidden upgrade content): floor, wainscot, upper walls, table tops, chair shells, booth/stool seats; office/staff tables are left alone. Applied on plot load after `UpgradeService.applyPlot`. Dev hook `DevCommand("theme", id)`. Verified: real click buy of Space Station ($1,600 charged, toast, IN USE), Gold & Marble refused below level 14, every dining + annex part restyled, switch back to Classic leaves no Space parts; screenshot.

## UI fixes #25 + #26 (Account 1, 2026-11-07): Studio-verified
- The day-clock pill no longer covers the top-left of the Pizza Planet OS window or the POS order screen: `DayClock.covered` hides it, set by `Manager.open`/`close` and `POS.open`/`close`. Verified: hidden while open, back after Log off / Leave.
- The Recipes tab redraws the mastery rows live when a count changes (serves, new tiers) and keeps its scroll position. Verified: bronze reached with the tab open → "10 / 30 to 🥈 Silver" without reopening.

## Extension annex + PizzaBox v2 (TASKS #2, Account 1, 2026-11-07): Studio-verified
- **Annex bugs fixed** (they came from moving the east wall out): the east wall's wood panelling stayed in the opening after buying the Dining Room Extension and blocked the way in, and the east poster and neon sign floated in mid-air. The panelling now belongs to the wall section the annex removes; the east poster and neon sign hide with `HideWhen = expansion_1`. The annex got its own panelling, a cream back wall, a framed "PLANET PIZZERIA" poster and a neon sign that needs Neon Wall Signs too.
- **UpgradeService fix:** a show/hide rule nested inside a hidden upgrade model (the east neon sign inside the neon decor) was never checked, so buying the annex first and the neon decor second brought the old sign back. `applyPlot` now also checks rules inside hidden models, and a re-shown piece goes back into its home even when that home is hidden. Verified in both purchase orders.
- Walk test: the player walks straight from the dining room into the annex. No trees inside its footprint.
- PizzaBox v2 checked: the orbit ring lies flat around the logo, trim and tab look right.
- New helper `hangArt(ctx, x, z, yaw, text, color)` in RestaurantBuilder for framed posters.

## Rush tuning (Account 2, PR #4): Studio-verified + merged by Account 1 on 2026-11-07
- A rush's extra traffic scales with level (`Config/DayCycle.RushScale`: 35% at level 1 → 100% at level 8). Measured live with the new `DevCommand("traffic")`: level 1 lunch ×1.28 / dinner ×1.35 / late ×1.14; level 4 ×1.50 / ×1.63 / ×1.25; level 8 ×1.8 / ×2.0 / ×1.4; morning ×0.9 and afternoon ×0.8 unscaled. Matches the PR table exactly.
- Note: `DevCommand("open")` opens the doors without starting a shift, so no rush runs. Open with the real OPEN sign (or a bot press) to test rushes.

## Level-up popup (2026-11-07, Account 1)
- Several level-ups in a row now show as ONE popup (highest level, "Levels 2 → 4", rewards summed, every unlock listed) instead of a chain, and it closes itself after 12 s (`LEVEL_AUTO_CLOSE` in `Notifications.luau`). The old chain kept "LEVEL UP! 2" on screen while the HUD already said 3. The server sends each level-up once (verified). In Studio every session starts at level 1 because saving is off, so the level-2 popup appears early in every playtest; that's expected.

## Full-shift playtest (2026-11-07, Account 1)
A client-side test bot played a whole day through the real prompts in the new 81 x 66 layout: register + POS, dough → board → sauce/toppings → oven → box → pickup, colas, a supply run (Owner PC order → truck → back-door pallet → fridge), lunch + dinner rush, closing, day summary.
- **Works, no script errors:** every station, topping meshes on the board model, ~16 s bakes, deliveries to the moved pad/fridge, level-ups (1 → 3) with rewards, the summary card (9 orders, 11 pizzas + 5 drinks, $108 sales, $15.75 tips, shift bonus +$25.62 +40 XP).
- **Fixed:** newly unlocked ingredients started at 0 stock, so customers ordered new recipes the player couldn't make (guaranteed walk-outs). Level-ups now give one free starter box of each newly unlocked ingredient the player has none of (`GameConfig.UnlockStarterBoxes = 1`, in `ProgressService.addXP`). Verified: level 3 → pepperoni, mushroom, ham, onion, pepper all stocked, toasts shown.
- **Fixed:** HUD status said "1 orders"; now "1 order".
- **Fixed (TASKS #24):** the level-up popup no longer covers the day-summary card. `ShiftService.finish` adds the bonus XP before sending the summary, so a bonus level-up arrived first. `Notifications` now holds level-ups while a `DaySummary` card is open and steps an open level-up aside when one appears; they come back in order once the card is closed. Studio-verified both ways (level-up first, summary first).
- **Observed, not fixed:** a solo level-1 player with one oven struggles in the dinner rush (8 walk-outs, rating 4.00 → 2.44, though part of that was the bot idling) - see TASKS #18.
- **Test tooling:** `DevCommand("queue")` returns the front customer's wish and the open orders. If you script prompts with `InputHoldBegin/End`, point the camera at the part first: the game only accepts prompts that are on screen, which is why scripted presses were flaky.

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
- 54 Blender meshes are in. They load in parallel at server start (about 3 s in Studio, was about 25 s sequential); anything not loaded after 45 s falls back to procedural parts with a warning. MeshService loads meshes one by one, so the server takes about 25 s to build in Studio; loading them in parallel would speed that up.
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
