# Metabolism

The Metabolism is the main biochemical planning board.

## Current Direction

Molecules are represented as colored marbles/gems placed on a grid. The detailed molecule structure appears in hover popups and in the enzyme designer. Reactions are represented by orthogonal arrows. Flux particles move along arrows and shift color from substrate to product.

## Board Rules

- Molecule nodes snap to grid cells.
- Target sink nodes also snap to grid cells.
- Membrane import source nodes sit on the membrane boundary.
- Imported molecules should appear just inside the cell, near the membrane transporter.
- Arrows should only use straight horizontal/vertical segments.
- Arrows should stop outside the marble, not inside it.
- Input and output arrows should avoid using the same side of a node.
- When two outgoing arrows share an origin, their lanes should be visibly separated.
- The board camera and zoom should persist when leaving and returning to the view.

## Target Sinks

Target sinks are special nodes. They represent conversion of a molecule into a resource rather than a normal product pool.

Initial targets:

- amino acid sink: converts simplified amino acid molecule into amino acid/protein resource,
- DNA point sink: converts future DNA-like molecule into DNA points.

## Flux Particles

Flux particles should be cheap to draw. They should not be individual heavy scene nodes. They should be drawn in batched logic inside the workspace control.

Particles should:

- be visible inside marbles as storage feedback,
- move along arrows proportional to reaction speed,
- have small random offsets so flux feels alive,
- preserve animation speed when zoom changes,
- use molecule color and transition toward product color.
