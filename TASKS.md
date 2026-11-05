# Tasks

Claim a task by putting your account in **Owner** and committing. Move finished tasks to **Done** with the date.

## Open

| # | Task | Area | Owner | Notes |
|---|---|---|---|---|
| 1 | Full playtest of the pizza flow + customer loop; fix every bug found | QA | Account 1 | Highest priority. Start a server, flip the OPEN sign, serve 5 orders |
| 2 | Re-test lighting after the exposure fix; tune interior light balance | Visual | — | Set Lighting.Technology = Future first |
| 3 | Sound pass: fill `SoundIds.luau` with licensed / free Creator Store audio | Polish | **Account 2 (suggested)** | Keep ids in config only |
| 4 | Hide other players' prompts on the client (only show prompts in your own plot) | Interaction | **Account 2 (suggested)** | Check `Restaurant_*` OwnerUserId in Interaction.findPrompts |
| 5 | Blender pass: pizza box (open lid), kebab wrap, chair, pizza oven dome as MeshParts + `MeshIds.luau` with procedural fallback | Art | **Account 2 (suggested)** | See docs/ART_STYLE.md |
| 6 | Player hold/serve animations (arms forward when carrying), customer eating/idle variety | Animation | — | |
| 7 | Day/shift cycle (lunch/dinner rush, closing time, end-of-day summary + wages) | Gameplay | — | Inspired-by feature; design first in AI_MESSAGES |
| 8 | Daily goals / challenges with XP + cash rewards | Progression | — | Adds XP from "completing challenges" (prompt req.) |
| 9 | Recipe book: show a mini 3D preview (ViewportFrame) of each recipe | UI | — | FoodVisuals.build can render into a ViewportFrame |
| 10 | More content past level 12: desserts, garlic bread, calzone, sides | Content | — | Config-driven |
| 11 | Staff NPCs (cashier, cleaner) as late-game upgrades | Gameplay | — | |
| 12 | Mobile/tablet UI pass (scale HUD, bigger touch targets) | UI | — | Test with the Studio device emulator |
| 13 | Interior themes / decorations shop (restyle floors, tables, wall colours) | Expansion | — | |
| 14 | Published-place DataStore test (session lock, save on leave, BindToClose) | Data | — | Needs the owner to publish the place |

## Done
| Task | By | Date |
|---|---|---|
| Repo structure, Rojo project, docs | Account 1 | 2026-11-05 |
| Config: ingredients, recipes (pizza/kebab/drinks), upgrades, levels | Account 1 | 2026-11-05 |
| Services: data, progress, held items, stations, customers, supply, cleaning, upgrades, plots | Account 1 | 2026-11-05 |
| Procedural town + restaurant (kitchen, ovens, prep lines, kebab station, front counter, dining, storage, office, staff room, extension) | Account 1 | 2026-11-05 |
| Client: HUD, aim-to-interact, POS, Pizza Planet OS manager, toasts, level-up popup | Account 1 | 2026-11-05 |
