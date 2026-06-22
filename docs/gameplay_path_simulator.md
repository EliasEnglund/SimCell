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

Run the gameplay balance matrix:

```bash
godot --headless --path . --script tests/gameplay_path_simulator.gd -- --balance-matrix
```

Current scenarios:

- `baseline_import`: no enzymes, just glucose import.
- `tier1_carbon_cut`: builds lyase on glucose and measures product flow.
- `redox_push`: builds dehydrogenase, then reductase, to test NADH pressure.
- `atp_branch`: builds decarboxylase to test ATP-positive carbon-loss chemistry.
- `amino_attempt`: tries a rough early amino-acid route from glucose fragments.
- `candidate_scan`: lists valid first-step reactions from the starting molecule.

The balance matrix compares enzyme on/off and tuning cases:

- Import only.
- One lyase versus a handful of lyases.
- Slow/low-affinity versus improved enzyme parameters.
- Amino-acid route attempts with and without extra nitrogen.
- Controlled amino-route off-tests for aminase and oxygenase.
- NADH-producing oxidation with and without a reductive sink.
- ATP-positive carbon-loss chemistry.

For each case it reports measured glucose import, glucose consumption, glucose accumulation pressure, enzyme counts, `kcat`, `Km`, active pathway rates, utilization, final ATP/NADH/N/amino-acid values, NADH production and consumption, available DNA unlocks, a pass/fail/pressure verdict, ranked blockers, and the next unlock or design move.

The output tracks:

- Number of simulations included in the run.
- Step size used by the simulation loop.
- Starting resources and molecule pools.
- Starting transporter counts, per-transporter import/export rates, and total rates.
- Build assumptions for enzymes and transporters.
- First-target enzyme assumptions on glucose, including `kcat`, `Km`, and ATP/NADH/N/resource deltas.
- Per-scenario inputs and scheduled player actions.
- ATP, NADH, nitrogen, amino acids, and DNA points.
- Net resource rates at report points.
- Top molecule pools.
- Active pathways, queued enzyme counts, `kcat`, `Km`, rates, and resource deltas.
- Simple bottleneck warnings.

This is not meant to be final balance. It is a design tool for testing whether a proposed progression creates useful pressure, viable routes, and understandable bottlenecks.
