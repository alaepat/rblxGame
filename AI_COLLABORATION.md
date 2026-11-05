# AI Collaboration Guide

Two Claude accounts build Pizza Planet together. **Neither is the lead.** Both can design systems, refactor, fix bugs, add features, and challenge each other's decisions. The repository is our shared memory: if it isn't written here, the other account doesn't know it.

| Account | Message file | Branch prefix |
|---|---|---|
| Account 1 (started the repo) | `AI_MESSAGES/ACCOUNT1.md` | `a1/` |
| Account 2 | `AI_MESSAGES/ACCOUNT2.md` | `a2/` |

## Mandatory sync protocol (from the owner, verbatim)

**Before every development session**
1. Fetch and pull the latest repository changes.
2. Read DEVELOPMENT_STATUS.md.
3. Read TASKS.md.
4. Read your incoming AI_MESSAGES file.
5. Check recent commits and changes made by the other account.
6. Check for conflicts before editing files.

**After every completed feature**
1. Test the implementation.
2. Commit your changes with a descriptive commit message.
3. Push your branch to GitHub.
4. Update DEVELOPMENT_STATUS.md.
5. Update TASKS.md.
6. Write a message to the other account describing what you implemented, which files changed, what the other account needs to know, any unfinished work, any possible conflicts, and any opportunities for further development.

**Communication rules**
- Never assume the other account knows about your changes.
- Never leave important information only in your Claude conversation.
- Always check for new commits before starting another task.
- Always read incoming messages.
- Always leave outgoing messages after meaningful development.
- Do not overwrite unmerged work.
- Never claim something was uploaded if the GitHub push failed.

You are equal development partners. Neither account manages the other. Both must maintain the repo and the communication system independently. Upload and document each finished feature rather than waiting until the whole game is done. If the other account has made new changes, understand and integrate them before continuing. **This protocol is mandatory for every session.**

The owner's full original brief is in [`docs/GAME_PROMPT.md`](docs/GAME_PROMPT.md).

## Before you start a session

1. `git pull` on `main`, then `git log --oneline -20` to see what changed.
2. Read `DEVELOPMENT_STATUS.md`, `TASKS.md`, and the **other** account's message file.
3. Check open PRs and remote branches (`git branch -r`, `gh pr list`) so you don't edit files someone else has in flight.
4. Claim a task in `TASKS.md`: put your account name in the **Owner** column and commit that change on its own (`git commit -m "tasks: claim <task>"`) so the claim is visible quickly.

## While you work

- Work on a feature branch (`a1/kebab-polish`, `a2/sound-pass`). Small, obviously-safe fixes (typos, docs) can go straight to `main`.
- Keep commits focused, with messages that explain *why*.
- Stay inside the architecture in `docs/ARCHITECTURE.md`. If you need to change it, update the doc in the same PR.
- **Config, not code**: new recipes, ingredients, upgrades and prices go in `src/shared/Config/*`. Systems read from config.
- **Server authority**: money, XP, stock and order validation only ever happen on the server.
- Never delete or rewrite the other account's work without discussing it first, in your message file or a PR comment.

## When you finish

1. Open a PR into `main` (or merge your own branch if the change is small and tested). Describe what you tested in Studio.
2. Update `DEVELOPMENT_STATUS.md` (what works, what's broken).
3. Update `TASKS.md` (mark done, add new tasks you discovered).
4. Write a dated entry at the **top** of your message file: what you did, what you need from the other account, and anything risky.

## Reviewing each other

- Either account can review or merge the other's PR. Leave review comments on anything you'd do differently. Disagreement is welcome, but keep it specific.
- If you think a PR is wrong, say so in a comment and propose an alternative. Don't silently revert it.

## Syncing code into Studio

Use Rojo (`rojo serve` + the Studio plugin, see README). The world is generated from code, so there is no place file to merge. If you can only reach Studio through the Roblox Studio MCP (no Rojo), paste scripts into the same paths that `default.project.json` maps, and make sure the repo copy stays the source of truth.

## Definition of done

- No errors in the Studio output on Play.
- The feature works end-to-end in a playtest (describe the steps in the PR).
- Config-driven where it makes sense, and documented in `docs/ARCHITECTURE.md` if it adds a new system.
