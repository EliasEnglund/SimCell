# Rendering Systems

SimCell mixes UI rendering, custom 2D drawing, generated bitmap assets, and 2.5D effects.

## Current Rendering Areas

- Molecule structure drawing: `scripts/ui/molecule_canvas.gd`.
- Metabolism board drawing: `scripts/ui/metabolism_workspace.gd`.
- Membrane/cell views: `scripts/ui/main.gd` and `scripts/ui/cell_view.gd`.
- Runtime/generated assets: `assets/runtime/`, `assets/art_lab/`, and focused asset folders.

## Guidelines

- Keep high-frequency particles batched in `_draw` or equivalent lightweight code.
- Avoid creating many Node instances per particle.
- Keep zoom-invariant strokes for board elements where possible.
- Keep reference images separate from runtime assets.
- Use generated bitmap art when a polished illustration/sprite is needed.
- Use code-native drawing when the graphic must respond exactly to state or geometry.
