# Sim Cell

Sim Cell is a Godot 4.6.x PC desktop prototype for a cellular biochemistry simulation game.

Open the project with:

```sh
godot --editor --path .
```

Run the smoke test with:

```sh
godot --headless --path . --script tests/simulation_smoke_test.gd
```

The current prototype focuses on the enzyme/metabolism core: graph-rendered molecules, a generated metabolic landscape, full-screen enzyme designer, lyase/reductase target selection, blueprint auto-queueing, and a numeric metabolism simulation running at 4 ticks/sec.

## Project Documentation

Start with:

- `AGENTS.md` for agent workflow and verification rules.
- `DESIGN.md` for the current game design direction.
- `ARCHITECTURE.md` for the technical structure.
- `ROADMAP.md` for the current development path.
- `QUALITY.md` for acceptance standards.
- `TESTING.md` for validation commands.
- `docs/handoffs/current-status.md` for the latest project state.

Focused design and implementation notes live under:

- `docs/product/`
- `docs/design/`
- `docs/engineering/`
- `docs/qa/`
- `docs/handoffs/`
