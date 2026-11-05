# Development Status

_Last updated: 2026-11-05 by Account 1_

## Verified in a Studio playtest
- The server boots with no script errors. The town and the player's restaurant generate (about 1,070 parts and 32 active stations at level 1), and the player spawns inside.
- The HUD renders (level/XP, money, rating, cleanliness, open/closed status, the unsaved-progress warning) and the customer-facing menu boards fill from config.
- DataStore falls back to a temporary profile in an unpublished place (expected).

## Written but NOT yet verified end-to-end
These are implemented, but a full playthrough hasn't been done yet. Test them first.
- Pizza flow: dough → board → sauce → toppings → oven (cook %, ready/burnt) → box → serve
- Customer NPCs: walk in, queue, the POS order screen, waiting, collecting, paying, patience, angry walk-outs
- Kebab station (upgrade), fryer + chips, drinks fountain, heat shelf, bin
- Supplies (office PC) → delivery pallet → put away into dry/fridge/freezer, capacity limits, emergency delivery
- Upgrades (visible models, effects), cleaning (rubbish, messy counters), level-up popup
- Aim-to-interact controller (cursor raycast + custom prompt UI)

## Known issues / gaps
- **Overexposed lighting** in the first playtest. The repo already has a fix (lower ceiling-light brightness, bloom, exposure), but it hasn't been re-tested in Studio yet.
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
