# Exploration View

The exploration view is the microscopic travel layer.

## Visual Direction

Use the referenced Cell Simulator image as direction for scale and distance: the player cell is small relative to the screen, environmental objects sit at different distances, and the medium feels cloudy with particles. Do not copy the UI from the reference.

The environment should include:

- sparse bacteria,
- nutrient deposits,
- sulfur or nitrogen deposits,
- small virus-like particles,
- cloudy underwater medium,
- readable depth and distance.

## Movement Direction

Movement should not feel like an arcade ship with perfect steering. Once the player has built a flagellum, they choose a direction and invest movement energy. The flagellum spools up and pushes the cell in that direction with drift.

Prototype controls:

- A/D adjusts intended direction.
- W increases propulsion energy.
- S decreases propulsion energy.
- The cell turns gradually toward the intended direction.
- Movement includes random/current-like drift.

Later controls can become explicit UI controls for selecting direction and energy investment.
