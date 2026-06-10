# Membrane View

The membrane view shows a cross-section between extracellular space and cytoplasm.

## Current Direction

The center view should show:

- outside region above the membrane,
- inside/cytoplasm below the membrane,
- a curved membrane with phospholipids,
- membrane transporters attached to the membrane,
- source molecules floating outside and inside,
- visible flow direction for import/export.

The right panel lists outside molecules. The left panel lists active imports and exports based on existing transporters.

## Initial Outside Molecules

- glucose,
- formic acid,
- ethanol,
- pyruvate,
- H2,
- NO3,
- SO4.

Glucose should have the highest starting amount. Other molecules should have lower amounts.

## Interaction Rules

- Hovering an outside molecule in the right list highlights matching molecules in the center view and dims others.
- Clicking a right-list molecule selects it.
- Clicking the same item again or empty list space deselects it.
- Selecting a molecule reveals a build importer button.
- Building an importer queues a membrane transporter.
- Transporters of the same type should visually group along the membrane.
- Dragging the membrane should feel like rotating a curved cell surface. Transporters and molecules should move along the same arc, not pan in flat screen-space rows.

## Visual Direction

The membrane should feel layered and alive, but must remain performant. Prefer small shader-like motion, sprite cycling, or low-count animated layers over thousands of independently moving objects.
