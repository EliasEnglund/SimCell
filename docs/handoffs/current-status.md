# Current Status

Last updated: 2026-06-10.

## Project State

SimCell is a Godot 4.6.x desktop prototype. The strongest current system is the enzyme/metabolism/membrane loop, but it is still under active iteration.

## Working Features

- Title screen.
- Top resource bar with hover popups.
- Bottom view navigation.
- Cell status view prototype.
- Exploration view prototype with flagellum propulsion direction and drift.
- The Metabolism grid workspace.
- Molecule marbles with storage particles.
- Orthogonal reaction/import arrows.
- Hover popups for molecules and reactions.
- Enzyme designer with multiple enzyme classes.
- Protein builder queue.
- Membrane view with outside molecule list, selection, and importer building.
- DNA tech tree prototype.
- Art Lab for visual experiments.
- Simulation smoke test.

## Current Friction

- Metabolism route layout is still being refined.
- Molecule visual style is close but not final.
- Membrane art has gone through several failed/prototype approaches and needs a clean direction.
- Cell status and exploration views need more polish and a shared state model for nearby objects.
- Many UI systems are still concentrated in `scripts/ui/main.gd`.

## Recent Direction

The metabolic landscape is moving from full molecule structures on the board to grid-based marbles with hover details. This is intended to make large metabolic networks easier to read.

The membrane view should become a clean management screen: center membrane visualization, right outside molecule list, left import/export inventory.

The old combined cell/exploration view has been split. Cell view should become a status/progression scene; Exploration view should handle travel and nearby environmental context.

## Next Useful Work

- Stabilize metabolism arrow routing and drag behavior.
- Make importer/enzyme build feedback unmistakable.
- Improve molecule hover popups.
- Start extracting large UI sections from `main.gd`.
- Add screenshot-based visual QA workflow.
