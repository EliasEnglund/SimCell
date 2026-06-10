# Godot Architecture Notes

Use Godot 4.6.x.

## Scene Strategy

The prototype currently builds many views in code. This is acceptable while the design is fluid. As views stabilize, split large UI sections into dedicated scripts/scenes.

Candidates for extraction:

- metabolism side panel,
- membrane side panels,
- resource bar,
- enzyme designer,
- protein builder lanes,
- DNA tech tree nodes.

## Input Strategy

Each workspace should own its own pan/zoom/drag behavior. Global UI should not guess at workspace interactions.

Rules:

- drag objects only when the hit target is clear,
- empty drag pans workspace,
- release should finish drag immediately,
- click should select only if drag distance was small,
- camera state should persist per view where useful.

## Data Strategy

Keep hardcoded data only while mechanics are changing. Move to structured resources/data when:

- designers need to edit without code,
- multiple systems need the same data,
- tests need stable fixtures,
- balance passes become frequent.
