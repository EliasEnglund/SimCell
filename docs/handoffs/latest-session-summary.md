# Latest Session Summary

Last updated: 2026-06-10.

## Summary

The project adopted a harness engineering structure inspired by OpenAI and Anthropic recommendations. Root-level and nested documentation now define how agents and humans should work with the project.

## Important Context

The user wants long-term cleanup, source-of-truth documentation, and structured iteration. Future agents should not rely on chat memory. Read `AGENTS.md` and the relevant docs before making changes.

## Current Technical Baseline

Validation commands:

```sh
godot --headless --path . --quit-after 1
godot --headless --path . --script tests/simulation_smoke_test.gd
```

These should pass before code changes are reported complete.
