# Development Status

_Last updated: 2026-11-05 by Account 1_

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

## Not yet verified end-to-end
- Angry walk-outs, messy-counter wiping, emergency delivery, the extension annex (level 10)
- Real DataStore saving (enable **Game Settings → Security → Enable Studio Access to API Services**, then rejoin)

## Known issues / gaps
- Roblox only shows a prompt when its part is on screen, so players must look at what they interact with (that's intended).
- Stainless steel (Metal material) looks quite dark in enclosed rooms. Consider a lighter colour or SmoothPlastic for counter bodies.
- Box items say "Wrapped Loaded Fries"; they should say "Closed".
- `Lighting.Technology` must be set to **Future** by hand (scripts can't set it).
- No sound ids yet: `SoundIds.luau` is all empty, so the game is silent.
- Other players can see (but not use) prompts in your restaurant. The server rejects their use, but the client still draws the panel.
- NPCs walk straight lines between nodes (no pathfinding), so layout changes must keep the paths clear.
- No custom Blender meshes yet. All visuals are procedural parts.
- No day/shift cycle, challenges/daily goals, staff, or delivery orders yet (see TASKS.md).

## Phase progress (from the master prompt)
| Phase | State |
|---|---|
| 1 Environment | Procedural restaurant, town, lighting done; visual polish ongoing |
| 2 Interactions | Done (needs playtest) |
| 3 Food | Pizza + kebab + drinks + chips done (needs playtest) |
| 4 Customers | Done (needs playtest) |
| 5 Progression | XP / levels / unlocks / money done |
| 6 Expansion | Upgrades, stock, deliveries, extension annex done |
| 7 UI | HUD, POS, manager, level-up, toasts done |
| 8 Multiplayer & saving | Per-player plots + DataStore done; needs a published-place test |
| 9 Polish | Not started (sound, animations, VFX, optimisation) |
