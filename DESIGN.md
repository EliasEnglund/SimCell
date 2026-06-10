# Design

SimCell is a PC desktop game about engineering a living cell from the inside. The player imports molecules, designs enzymes, routes metabolism, builds proteins and transporters, and spends DNA points to unlock stronger biological technology.

The game should feel like a living biochemical factory: readable, technical, visually alive, and driven by meaningful tradeoffs.

## Core Loop

1. Explore the environment and import source molecules.
2. Arrange metabolism on the metabolic board.
3. Design enzymes that transform substrates into useful products.
4. Convert target molecules into resources such as amino acids, ATP, NADH balance, and DNA points.
5. Spend resources to build enzymes, transporters, and later cellular structures.
6. Use DNA research to unlock new enzyme classes, elements, transport options, and efficiency tiers.
7. Adapt the cell to new goals and environmental pressure.

## First Goal

The first playable goal is to convert imported glucose-like substrate into simplified amino acid resource. The target amino acid molecule is represented as an `N-C-COOH` style product. When produced, it disappears from the board and becomes amino acid/protein points.

The next strategic layer is DNA points. DNA should be represented by a larger molecule, likely a five-carbon ring with nitrogen and phosphorus decoration. DNA points unlock the tech tree.

## Important Decisions

The player should make decisions such as:

- which molecule to import,
- where to place reaction nodes on the metabolism board,
- which enzyme path to build first,
- whether to spend amino acids on enzymes or membrane transporters,
- whether to generate or consume ATP,
- how to balance NADH production and consumption,
- which DNA branch to unlock next.

## View List

The six current views are:

- Cell view: navigation, environment, outside resources, threats, cell identity.
- The Metabolism: grid-based metabolism board with marbles, arrows, flux, target sinks, and enzyme hover previews.
- Membrane view: cross-section membrane, transporters, outside molecules, import/export inventory.
- Protein Builder: ribosome/protein synthesis queue and completed proteins.
- DNA Tech Tree: research tree driven by DNA points.
- Art Lab: temporary prototyping view for art styles, icons, and visual comparisons.

## Tone

The UI should feel scientific and polished, not cartoonish. It can be colorful, but the base should remain dark, biological, and high-contrast. Motion should communicate simulation, not distract from decision making.
