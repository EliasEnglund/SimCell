# Cell View

The cell view is the world/exploration layer.

## Current Direction

The player should start in this view after pressing Play on the title screen. The cell swims in a cloudy microscopic environment with deposits, other bacteria, and small threats.

## Movement

- W moves forward quickly.
- S backs up slowly.
- A and D rotate the cell.
- The flagellum should animate during movement and rotation.

## Zoom States

The cell view should morph between two states:

- close-up state: the cell fills the screen and internal activity is visible,
- travel state: the cell is small enough to navigate the environment.

The transition should be seamless based on zoom level.

## Environment

Add sparse but readable objects:

- sugar deposits,
- sulfur deposits,
- nitrogen sources,
- other bacteria,
- small virus-like particles,
- cloudy water particles behind the cell.

Particles and environment effects should not obscure the cell.
