# Regression Tests

## Current Automated Test

`tests/simulation_smoke_test.gd` is the main regression test. It should stay fast and cover the core model.

Run:

```sh
godot --headless --path . --script tests/simulation_smoke_test.gd
```

## Add Test Coverage When

- a new enzyme class changes molecule graph rules,
- resources are added or rebalanced,
- target molecule conversion changes,
- transport rules change,
- DNA research unlock rules change,
- save/load is modified.

## Future Test Ideas

- deterministic molecule graph fixtures,
- enzyme class table tests,
- save/load round trip,
- route layout sanity test,
- screenshot capture for major views.
