# Architecture

The project uses Godot 4.6.x and GDScript.

Core rule: simulation logic must be separate from presentation. UI reads from `SimulationState`; it does not own rules for resources, enzyme outputs, transport rates, or tech unlocks.

Current shape:

- `scripts/core/data_catalog.gd` defines molecule, transporter, enzyme, protein, and tech data.
- `scripts/core/simulation_state.gd` owns runtime state and all simulation ticks.
- `scripts/core/save_game.gd` stores and restores the current culture.
- `scripts/ui/main.gd` builds the first debug-playable UI.
- `scripts/ui/cell_view.gd` renders the 2.5D cell visualization.

As the project grows, move data out of hardcoded dictionaries into Godot resources or structured data files. Do that when designers need to edit content without changing scripts, not before.
