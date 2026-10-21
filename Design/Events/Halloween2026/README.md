# Halloween Night — November 2026

The event catalog is `ArrowGate/Levels/event-halloween-2026.json`. It contains 30 independent puzzles, labelled November 1–30, unlocked in order while the event is active. Only completed puzzles reveal their piece artwork; the full reward is revealed after all 30 puzzles are completed. IDs 10001–10030 are separate from campaign IDs.

Each puzzle has 150 arrows, at least three cells per arrow, no timer, and a verified removal solution. The final generation report is `Design/ArrowTrialHalloween2026/report.json`: 29–56 dependency layers, no more than 29 initially free arrows. Colour mapping preserves all paths and uses opaque colours with at least 4.5:1 contrast against white.

## Temporary testing access

The real event runs November 1 through November 30, 2026, in Bucharest time. Remove only `event.schedule.testingStartsAt` from the catalog to restore that schedule. Its current value enables testing from October 14. Progress is stored separately from campaign progress and each completed event puzzle counts once.

## Artwork and generation

The complete image, original 30-piece atlas, and exact ImageGen prompts are saved here. Assets are published under `ArrowGate/Assets.xcassets/Halloween 2026`.

`Scripts/prepare_halloween_event.py` extracts connected components from the atlas and prepares the initial scaffold. Piece 12 was subsequently replaced with the cropped `halloween-gate-closed-v2.png` to give it a sufficiently dense puzzle silhouette. Rerunning asset preparation would overwrite that replacement.

The final geometry is saved in `halloween-puzzles.json`. The baseline generation used `Scripts/point_shape_profiles_halloween2026.json`. Days 13, 14, 17 and 22 came from `halloween-refinement.json`; day 12 came from `halloween-gate-puzzle.json`. Their profile files and individual reports are retained. `Scripts/map_arrow_colours.py` then mapped colours onto the final set. Use `Design/Campaign/format_catalog.py` with explicit catalog paths when publishing; campaign chapter files must remain unchanged.
