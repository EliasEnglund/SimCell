# SimCell Agent Guide

This repository is the source of truth for SimCell. Do not rely on chat history when a repo doc exists.

## Start Here

Read these files before major work:

1. `README.md`
2. `DESIGN.md`
3. `ARCHITECTURE.md`
4. `ROADMAP.md`
5. `QUALITY.md`
6. `TESTING.md`
7. `docs/handoffs/current-status.md`

For focused work, also read the relevant document under `docs/product/`, `docs/design/`, `docs/engineering/`, or `docs/qa/`.

## Working Rules

- Keep simulation rules in `scripts/core/`, not in presentation code.
- Keep UI and rendering code in `scripts/ui/`.
- Clean up old code while changing nearby systems. Do not leave obsolete prototype paths alive.
- Prefer small, readable systems over speculative abstractions.
- Update docs when gameplay assumptions, visual direction, or workflows change.
- Preserve user-created files and unrelated worktree changes.
- Use reference assets only as references unless they are explicitly promoted to runtime assets.

## Verification

Run these before reporting code changes complete:

```sh
godot --headless --path . --quit-after 1
godot --headless --path . --script tests/simulation_smoke_test.gd
```

For visual/UI changes, run the game and inspect the relevant view. Use screenshots where possible.

## Review Standard

Implementation is not done when it merely compiles. A feature should be:

- understandable to a new player,
- visually coherent with the dark biological UI,
- documented if it changes design direction,
- covered by a smoke test when it touches simulation logic,
- free of obvious overlap, clipping, broken interaction, or dead UI.
