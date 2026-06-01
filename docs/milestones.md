# Milestones

## Milestone 0: Foundation

Status: started.

- Clean Godot 4.6.x desktop project.
- Living docs for vision, architecture, cleanup, and milestones.
- Core simulation object and data catalog.
- Debug-playable UI.
- Smoke test for the first simulation loop.

## Milestone 1: Core Biochemistry Loop

- Status: started.
- Molecule selection and reaction preview are implemented in the first debug-playable UI.
- Clear enzyme design flow now exists: select molecule, choose compatible transformation, preview input/output/cost/missing resources, design enzyme, run reaction.
- The action panel no longer rebuilds on every simulation tick; it refreshes only when action-relevant state changes.
- Membrane, protein, and DNA views now show affordability/availability before the player clicks.
- First balance pass for ATP drain, import rate, and protein costs.

## Milestone 2: Membrane And Environment

- External deposits with richer visual representation.
- Transporter UI showing gradients, rate, and ATP costs.
- Early starvation, toxicity, and hostile neighbor pressure as readable meters.

## Milestone 3: Protein Synthesis

- Dedicated protein queue UI with ribosome lanes.
- Enzymes, transporters, ribosomes, storage, and detox as consistent buildable machines.
- Mutation/improvement points only after the base protein loop feels coherent.

## Milestone 4: DNA Research

- Small tier 1 tech tree.
- Tech unlocks should add new player actions or new transformations.
- Manual acceptance path: produce DNA research and unlock chemotaxis.
