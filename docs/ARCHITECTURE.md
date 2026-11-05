# Architecture

## Runtime tree (via Rojo `default.project.json`)

| Repo path | Studio location | Notes |
|---|---|---|
| `src/shared/Config/*` | `ReplicatedStorage.Shared.Config` | **All tuning + content.** Recipes, ingredients, upgrades, levels, sound ids, numbers |
| `src/shared/Food/FoodLogic` | `ReplicatedStorage.Shared.Food` | Pure rules: can-add, cook state, recipe matching |
| `src/shared/Food/FoodVisuals` | same | Builds the 3D model for any item table (pizza, kebab, box, cup, supply box, ingredient pan) |
| `src/shared/Goals/DailyGoals` | `ReplicatedStorage.Shared.Goals` | Pure daily-goal rules: generation, progress, claiming, streaks, rollover (no services, so it is unit-tested in Lune) |
| `src/shared/Net` | `ReplicatedStorage.Shared.Net` | Creates/locates every RemoteEvent/RemoteFunction |
| `src/server/Main.server` | `ServerScriptService.Server.Main` | Bootstraps services in order (`init` for all, then `start`; DataService starts last) |
| `src/server/Services/*` | `ServerScriptService.Server.Services` | Game systems (below) |
| `src/server/World/*` | `ServerScriptService.Server.World` | Procedural world + restaurant builders |
| `src/client/*` | `StarterPlayerScripts.Client` | `Main.client` + Controllers + UI theme |

## Services (server)

Each service is a module with `init(services)` (receives the registry) and `start()`.

| Service | Responsibility |
|---|---|
| **DataService** | DataStore profiles: retries, soft session lock, autosave, BindToClose. Falls back to temporary (unsaved) profiles in unpublished Studio places. |
| **ProgressService** | Money, XP, levels, reviews/rating. Sends the per-player **State snapshot** (throttled), toasts, level-up and sound events. Other services add fields with `addStateProvider`. |
| **UpgradeService** | Buys upgrades, sums `effects` (cookSpeed, capacity, traffic, tip, queue), shows/hides upgrade models in the plot. |
| **GoalService** | Daily goals + streaks. Other services call `GoalService.record(player, event, amount, param)`; it rolls goals at the UTC reset (auto-paying finished-but-unclaimed rewards), validates `ClaimGoal`, pays through ProgressService, and adds `goals` to the State snapshot. Saved in `profile.daily`. |
| **HeldService** | The one item each player carries (server table + a welded visual). |
| **StationService** | Turns every part tagged `Station=<kind>` into prompts and runs its rules: Bin, PizzaBoard, KebabBoard, Topping, Oven, Fryer, BoxStation, HeatShelf, Trash, Fountain, Register, Pickup, Storage, OfficePC, OpenSign. Runs the cooking loop. |
| **CleaningService** | Rubbish after customers, messy counters after N uses, the cleanliness score. |
| **SupplyService** | Supply orders, timed deliveries to the back-door pallet, putting boxes away by category (dry/cold/frozen), storage capacity, emergency delivery. |
| **CustomerService** | NPC spawning (avatar from a random HumanoidDescription), queue, patience, POS order validation, serving, payment, tips, reviews, kitchen order screens. |
| **PlotService** | Builds `WorldBuilder` and assigns each player a plot, builds their restaurant with `RestaurantBuilder`, wires all services to it, handles spawns and cleanup. |

## Item model

Items are plain tables (see the header of `FoodLogic.luau`): `dough`, `pizza`, `bread`, `kebab`, `chips`, `cup`, `supply`. The server mutates them; `FoodVisuals.build(item)` renders them anywhere (in hand, on a board, in the oven, on a shelf). `FoodLogic.identify(item)` returns the recipe id a finished item satisfies.

## Interaction

All gameplay ProximityPrompts use `Style = Custom` and `Exclusivity = AlwaysShow`. The client `Interaction` controller raycasts from the cursor (the screen centre in first person or on mobile), finds prompts on the hit part (or its parents), outlines the object, draws its actions, and triggers them with `InputHoldBegin/End` on E / F / R, left click or tap. So players aim at a specific topping pan instead of fighting over the nearest prompt.

Stations decide their own prompt text and enabled state on the server in `StationService.refresh`, based on the owner's held item and stock.

## World building conventions

- `Build.luau` helpers take **local** coordinates relative to a ctx origin. `y = 0` is the floor. Sub-builders face **+Z**.
- Interactive parts are tagged with `B.station(part, kind, label, attrs)`. Use an invisible `B.hitbox` when the visual is made of many small parts, and parent the hitbox inside the visual's Model so the hover outline wraps it.
- `ItemAt` attachment = where an item sitting on the station is drawn.
- Upgrade content: put it in a Model with attribute `UpgradeId`. Placeholders it replaces get `HideWhen = <upgradeId>`.
- Navigation nodes live in `Restaurant.Nodes`: `CustomerSpawn, DoorOutside, DoorInside, Lobby, Queue1..6, Wait1..6, PickupSpot, RegisterLook, PlayerSpawn, DeliveryPad`.
- SurfaceGui faces: a part's **Back** face points +Z (toward the street), and **Front** points -Z.

## Remotes

See the header of `src/shared/Net.luau`. Client→server calls are RemoteFunctions that return `(ok, message)`. Every argument is validated server-side.

## Daily goals

Content and numbers: `Config/Challenges.luau` (templates with level/upgrade gates, target scaling, reward formulas, streak bonus). Rules: `Shared/Goals/DailyGoals.luau`. Server: `GoalService`. Client: `Controllers/Goals.luau` (the 🎯 Goals button under 📖 Recipes, with a badge for claimable rewards).

Events currently recorded:

| Event | Sent from |
|---|---|
| `order`, `earn` (price + tip), `tip`, `happy` (patience ≥ `GameConfig.HappyPatience`) | `CustomerService.completeOrder` |
| `serve_kind` (param = recipe kind), `serve_recipe` (param = recipe id) | `CustomerService.serve` |
| `clean` | `CleaningService.rewardClean` |
| `bake_perfect` | `StationService` oven take-out while the pizza is "cooked" |

Goals are deterministic per (day, userId, level, upgrades), so the same player gets the same goals all day on any server.

## Offline tests

`lune run tests/run.luau` (Lune 0.10) runs `tests/unit/*.spec.luau`. `tests/lib/Loader.luau` mirrors the Rojo tree with fake instances so modules can `require(script.Parent.X)` outside Studio. Pass fakes for services or modules that touch the live game (see `GoalService.spec` and `GoalsUI.spec`). `Compile.spec` compiles every file in `src/`. These tests don't replace a Studio playtest.

## Adding content

- **New recipe**: add it to `Recipes.luau`. If it needs a new ingredient, add that to `Ingredients.luau`, then add a pan for it to the right rail in `RestaurantBuilder` (pizza: `row1`/`row2`; kebab: `salad`/bottles).
- **New upgrade**: add it to `Upgrades.luau`. For a visual, add a Model with `UpgradeId` in `RestaurantBuilder`. For gameplay, read `UpgradeService.effect(player, "<effect>")` where it matters.
- **New station type**: tag a part with `Station = "<Kind>"`, then add a branch in `StationService.refresh` and an `actions.<Kind>` function.
- **New daily goal**: add a template to `Config/Challenges.luau`. If it needs a new event, call `S.GoalService.record(player, "<event>", amount, param)` where it happens and add the event to the list above.
