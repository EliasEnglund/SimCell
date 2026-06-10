# Simulation State

`SimulationState` is the authoritative runtime model.

It owns:

- molecule types and amounts,
- outside molecule amounts,
- resources and rates,
- transporter counts and build queue,
- enzyme blueprints and protein queue,
- active enzymes,
- reactions,
- DNA research state,
- fixed-time simulation ticks.

## Rules

UI should call methods on `SimulationState`; it should not mutate internals directly unless no method exists yet. If a UI action needs a new behavior, add a method to `SimulationState`.

Whenever simulation behavior changes, update or add tests in `tests/simulation_smoke_test.gd`.

## Rates

The simulation should prefer explicit rate fields over inferred UI state. Views should display rates but not compute gameplay outcomes.
