# SimCell UI Visual Guidelines

## Current Critique

- The strongest views use a dark biological base, cyan borders, soft glow, and compact information density.
- The weakest UI moments come from default gray controls, unstyled sidebars, and atlas sprites that are cropped or stretched inconsistently.
- Every major view should feel like part of the same scientific instrument: dark glass panels, cyan section headers, restrained highlights, and molecule-specific accent colors.

## View Shell Rules

- Use the top bar as the single source of the current view title.
- Side panels should use dark teal or blue-black fills with cyan borders and subtle glow.
- Avoid default Godot gray panels and buttons in player-facing views.
- Keep side panel widths consistent: roughly 330-360 px for detailed sidebars.
- Use scroll containers for lists or details that can grow over time.

## Row And Button Rules

- List rows should be dark, compact, and readable.
- Selected and hovered rows should use the relevant molecule or system accent color.
- Buttons should share the same cyan/green bordered style unless a view has a specific risk action.
- Avoid oversized cards inside side panels; dense rows are easier to scan during play.

## Art Asset Rules

- Sprite atlas crops must include detached glow, bubbles, shadows, and small particles.
- Exploration and Map Designer must use the same crop metadata so saved maps preview the same as gameplay.
- Preserve source aspect ratio when drawing generated bitmap assets.
- Use generated sprites for environmental objects and reserve code-drawn graphics for overlays, highlights, arrows, and UI feedback.

## Metabolism-Specific Direction

- The metabolism board should stay full-bleed and readable.
- The left rail should provide inventory and selection context, not compete with the board.
- Molecule rows should use molecule color accents, not neutral gray.
- Hover cards for enzyme arrows should be compact, information-rich, and visually connected to the selected pathway.
