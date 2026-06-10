# Molecule Style

Molecule rendering has two contexts:

- metabolic board: small readable marbles and hover previews,
- enzyme designer: larger tactile molecule structures.

## Board Representation

The board uses colored marbles/gems for molecule pools. The full structure appears on hover. This keeps the metabolic landscape readable as pathways grow.

Marbles should:

- be small enough for grid planning,
- have a colored rim or body that identifies molecule family,
- show storage particles inside,
- have readable formula and amount nearby,
- keep stroke width stable under zoom.

## Structure Representation

Molecule previews and enzyme designer structures should use consistent atom/bond rendering.

Target style:

- carbon: gray glossy atom,
- oxygen: red glossy atom,
- phosphorus: purple glossy atom,
- nitrogen: blue glossy atom,
- sulfur: yellow glossy atom,
- bonds: pale blue-white with black outline/shadow,
- double bonds: two separate visible strokes.

## Current Preference

The selected molecule style direction came from the Art Lab variant closest to reference style 5, then additional refinement: thinner black stroke, less bright inner rim, clearer atom gradient, and visible bond spacing.
