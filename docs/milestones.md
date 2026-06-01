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
- Molecules are now structural atom/bond graphs, starting with a glucose-like C₆O₆ molecule.
- Metabolism view shows current in-cell molecule pools and a generated metabolic landscape.
- Enzyme designer is a full-screen separate view opened from a selected molecule.
- Lyase highlights valid C-C bonds and previews split products.
- Reductase highlights valid C-O bonds and previews single/double bond toggles.
- Confirming a design creates an enzyme blueprint, auto-queues it in protein builder, and activates it after a short build time.
- Numeric metabolism runs on fixed 4 ticks/sec and uses a simplified Michaelis-Menten style rate.
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
