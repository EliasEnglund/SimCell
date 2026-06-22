# Gameplay Path Simulator

This is a lightweight balance harness for testing early SimCell economy ideas without opening the full UI.

Run all prototype paths:

```bash
godot --headless --path . --script tests/gameplay_path_simulator.gd
```

List available paths:

```bash
godot --headless --path . --script tests/gameplay_path_simulator.gd -- --list
```

Run one path:

```bash
godot --headless --path . --script tests/gameplay_path_simulator.gd -- --scenario amino_attempt
```

Current scenarios:

- `baseline_import`: no enzymes, just glucose import.
- `tier1_carbon_cut`: builds lyase on glucose and measures product flow.
- `redox_push`: builds dehydrogenase, then reductase, to test NADH pressure.
- `atp_branch`: builds decarboxylase to test ATP-positive carbon-loss chemistry.
- `amino_attempt`: tries a rough early amino-acid route from glucose fragments.
- `candidate_scan`: lists valid first-step reactions from the starting molecule.

The output tracks:

- ATP, NADH, nitrogen, amino acids, and DNA points.
- Net resource rates at report points.
- Top molecule pools.
- Active pathways and rates.
- Simple bottleneck warnings.

This is not meant to be final balance. It is a design tool for testing whether a proposed progression creates useful pressure, viable routes, and understandable bottlenecks.
