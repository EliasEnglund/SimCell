# Quality Standard

SimCell should be developed as a long-term game project, not a throwaway prototype.

## Acceptance Criteria

A change is acceptable when:

- it compiles without Godot parser errors,
- the smoke test passes if simulation logic changed,
- the relevant view can be opened in-game,
- core interactions still work,
- visuals do not overlap or clip in normal use,
- the implementation fits the architecture,
- obsolete code is removed or clearly marked for near-term cleanup,
- docs are updated when design direction changes.

## Visual Quality

Every screen should be judged on:

- readability at normal desktop scale,
- consistency with the dark biological UI,
- clear hierarchy between primary workspace and side panels,
- restrained glow effects,
- no accidental transparency, clipping, or jitter,
- movement that communicates purpose.

## Gameplay Quality

Every new mechanic should answer:

- What decision does this create?
- What feedback tells the player what happened?
- What resource, risk, or opportunity changes?
- How does it connect to metabolism, membrane, protein, or DNA systems?

## Cleanup Rule

When replacing a prototype system, remove the old behavior after the replacement works. Do not keep parallel versions unless the Art Lab is explicitly comparing them.
