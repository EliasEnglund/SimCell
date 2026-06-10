# Testing

## Required Commands

Parser/runtime smoke:

```sh
godot --headless --path . --quit-after 1
```

Simulation smoke:

```sh
godot --headless --path . --script tests/simulation_smoke_test.gd
```

Run game:

```sh
godot --path .
```

## What The Smoke Test Should Cover

The smoke test should continue to cover:

- starting glucose and outside glucose source,
- membrane import rates,
- transporter queue/build completion,
- molecule selection and deselection,
- enzyme valid targets,
- enzyme product previews,
- enzyme blueprint creation,
- protein queue completion,
- active enzyme reaction output,
- target molecule conversion into resource,
- DNA research spending.

## Manual Visual QA

For visual changes, inspect the affected screen and check:

- no text overlaps,
- hover/click states are visible,
- dragged objects snap correctly,
- arrows point to the correct side of nodes,
- zoom does not distort strokes or particle speeds,
- panels stay readable,
- motion is smooth enough for the current prototype.
