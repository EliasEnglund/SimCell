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
