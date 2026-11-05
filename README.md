# Pizza Planet: Restaurant Simulator

A Roblox restaurant simulator. Every player runs their own pizza (and later kebab) takeaway, levels it up, and grows it into a big restaurant.

The gameplay *feel* is inspired by restaurant simulators like Burger Planet. **Every asset, model, script and UI here is original.** Do not import assets, branding or code from other games.

## Quick start (Studio)

1. Install [Rojo](https://rojo.space) 7.x (`winget install Rojo.Rojo`) and its Studio plugin (`rojo plugin install`).
2. Open an empty Baseplate place in Roblox Studio.
3. From the repo root, run `rojo serve`. In Studio, open the **Plugins → Rojo** panel and click **Connect**.
4. Press **Play**. The server generates the whole town and your restaurant from code.

The world is built entirely by scripts (`src/server/World`), so there is **no binary place file** to merge. Everything lives in Git.

> Studio note: Lighting → Technology can't be set from scripts. Set it to **Future** by hand in the place for the intended look.

## Offline tests

With [Lune](https://lune-org.github.io/docs) 0.10 installed, run this from the repo root:

```
lune run tests/run.luau
```

It compiles every source file and unit-tests the pure modules (daily goals, the goal service against fake services, and the goals panel UI). It's a quick check before a Studio playtest, not a replacement for one.

## Layout

```
src/
  shared/   -> ReplicatedStorage.Shared   (config, food rules + 3D food models, remotes)
  server/   -> ServerScriptService.Server (services + world builders)
  client/   -> StarterPlayerScripts.Client (HUD, interaction, POS, manager UI)
docs/       architecture + art style guide
AI_MESSAGES/  notes between the two AI developers
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the systems fit together, and [docs/ART_STYLE.md](docs/ART_STYLE.md) for the modelling rules.

## Collaboration

Two Claude accounts develop this as **equal partners**. Before working, read [AI_COLLABORATION.md](AI_COLLABORATION.md), [DEVELOPMENT_STATUS.md](DEVELOPMENT_STATUS.md), [TASKS.md](TASKS.md) and `AI_MESSAGES/`.
