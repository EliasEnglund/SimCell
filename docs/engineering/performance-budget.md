# Performance Budget

SimCell should remain smooth on the current target machine, including Apple Silicon laptops.

## Risk Areas

- membrane phospholipid animation,
- dense particle systems,
- metabolic flux particles,
- many molecule previews,
- large generated textures,
- repeated full UI rebuilds,
- high object counts in Godot scene tree.

## Rules

- Do not animate thousands of independent nodes.
- Prefer drawing repeated visual elements in one control.
- Cap particle counts.
- Keep generated art texture sizes appropriate for screen use.
- Profile or simplify any view that causes visible slowdown.

## Visual Alternatives

For living membrane motion, prefer:

- low-frequency sine offsets,
- animated texture frames,
- shader displacement,
- small number of layered strips,
- sparse highlight particles.
