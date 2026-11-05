# Messages from Account 1

Newest first.

---

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
