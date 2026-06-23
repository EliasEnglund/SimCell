# Enzyme Designer

The enzyme designer is entered from a molecule. The first click selects a molecule in the metabolism view; the second click opens the designer.

## Purpose

The designer lets the player choose an enzyme class and a target atom or bond. The system previews products, build cost, reaction speed, and resource effects.

## Current Enzyme Classes

- Lyase: breaks C-C bonds.
- Reductase: reduces double bonds or carbonyl-like structures.
- Dehydrogenase: oxidizes C-O to C=O and produces/uses NADH depending on rule direction.
- Oxygenase: adds oxygen.
- Decarboxylase: removes carboxyl-like groups and may interact with ATP.
- Amination: adds nitrogen.
- Desaturase: converts C-C to C=C and affects NADH.

## Design Direction

Early enzymes should be constrained and easy to understand. Later DNA unlocks should add alternatives, efficiency, stability, and resource coupling.

The player should understand:

- what bond or atom is targeted,
- what product will be created,
- whether ATP/NADH/N is consumed or produced,
- how fast the enzyme acts,
- how long the enzyme lasts,
- whether it can be built with current resources.

## Lyase Bond Strength

Lyase targets use a 0-100% bond-strength score. A plain C-C bond should be effectively stable at 100% and unavailable to early lyases. The score is lowered only by destabilizing chemistry:

- Direct C-COOH bonds are weak but controlled, roughly 40-45%.
- C=O-COOH bonds are very weak enzymatic targets, roughly 30%.
- Nearby carbonyls, phosphate, sulfur, and beta-keto-acid context can lower strength further, but these effects should not double-count the same structural feature.
- Bonds below 20% are considered unstable enough to break spontaneously. This should be rare and should not happen to the starting glucose-like molecule.

Weak lyase bonds should be visibly different in the designer: warmer color, stronger glow, and more electric stress. Stronger bonds should look cooler and more stable.

## Interaction Feel

The molecule should feel physical at designer scale. Atoms and bonds can be grabbed. Bonds should show resistance and electric feedback when pulled.

The designer rendering may be larger and more tactile than the metabolism board rendering, but the chemistry style should remain recognizable.
