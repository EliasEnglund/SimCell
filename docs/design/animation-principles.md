# Animation Principles

Animation should make the simulation feel alive and clarify state.

## Use Animation For

- molecule flux,
- membrane transport,
- enzyme reaction previews,
- protein build progress,
- DNA research progress,
- cell movement,
- subtle environmental particles.

## Avoid

- jittery procedural motion,
- high object counts,
- animations that change gameplay positions unexpectedly,
- motion that obscures small text or node connections,
- zoom-dependent speed changes.

## Performance Rule

Prefer batched drawing, shader-like effects, low-count particles, and sprite cycling over many independent scene nodes.
