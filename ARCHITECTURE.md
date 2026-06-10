# Architecture

SimCell is a Godot 4.6.x PC desktop project using GDScript.

The main architectural rule is separation of simulation and presentation. `SimulationState` owns rules, numbers, resources, enzymes, transporters, reactions, research, and ticking. UI scripts read state and send player actions back to the simulation.

## Current Core Modules

- `scripts/core/molecule_graph.gd`: molecule graph creation, normalization, formulas, signatures, and structural transformations.
- `scripts/core/simulation_state.gd`: runtime state, resources, reactions, transport, protein queues, DNA research, and fixed simulation ticks.
- `scripts/core/save_game.gd`: culture persistence.
- `scripts/ui/main.gd`: main UI shell, title screen, view switching, enzyme designer, protein screen, membrane panels, and resource bar.
- `scripts/ui/metabolism_workspace.gd`: grid-based metabolic board, molecule marbles, transport source nodes, orthogonal routes, hover popups, flux particles, and draggable layout.
- `scripts/ui/molecule_canvas.gd`: atom/bond rendering for molecule previews and enzyme target selection.
- `scripts/ui/cell_view.gd`: 2.5D cell/environment view.

## Design Direction

The long-term architecture should move toward:

- core simulation rules in small focused services or data-driven tables,
- reusable view widgets instead of all UI living in `main.gd`,
- explicit schemas for enzymes, molecules, transporters, and techs,
- visual tests or screenshot workflows for high-risk UI screens,
- save/load compatibility once the first gameplay loop stabilizes.

## Boundaries

Do not duplicate chemistry/resource rules in UI. If a button needs to know whether an enzyme can be built, ask `SimulationState`.

Do not hardcode one-off visual behavior into simulation state. If a route, molecule, or view needs presentation metadata, keep that in UI/layout state or data catalogs.

Do not preserve dead prototype systems. Remove them once replacement behavior is working and documented.
