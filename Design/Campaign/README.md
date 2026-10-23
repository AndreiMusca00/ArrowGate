# Pictarrow chapter workflow

> Pentru procesul actual complet, reguli și comenzi, citește [workflow-ul permanent](../LevelGeneration/WORKFLOW.md). Acest document descrie structura artwork-ului de capitol; referințele la unelte istorice nu garantează că acele unelte mai există.

Artwork and playable levels are two separate authoring stages.

## 1. Create the collectible

1. Create one polished complete illustration.
2. Design it as 24 separable semantic objects, such as the trunk, roof, bridge,
   birdhouse or lantern. These are transparent objects, never rectangular crops.
3. Export the complete illustration as `treehouse-3d-concept.png`.
4. Export the objects as `treehouse-3d-pieces/piece-01.png` through
   `piece-24.png`, in the order in which the player should collect them.
5. Record their normalized position and scale in the chapter's `assembly`
   section in `Backend/ContentSource/Levels/chapter-01.json`.

`prepare_chapter_artwork.py` only validates and copies those finished images
into `Backend/ContentSource/Artwork/Chapter 1`. It never creates levels and
never writes to `catalog.json`. Content artwork is published to Firebase and is
not compiled into the iOS app.

## 2. Author the levels

The 25 playable levels are authored separately and remain explicit entries in
their chapter file, such as `chapter-01.json`:

- Levels 1–24 reveal `EnchantedTreePiece01` through
  `EnchantedTreePiece24`.
- Level 25 uses `EnchantedTreeComplete`, represents the entire illustration
  and is a Nightmare level.
- Every board must be reviewed visually and validated by the game solver before
  it is published.

This separation lets us replace the future level-authoring tool without
touching the illustration or chapter presentation. It also prevents an artwork
operation from erasing or silently regenerating hand-authored puzzles.

## Catalog ownership

`catalog.json` is the small cloud-ready campaign index. It contains the catalog
version, shared configuration and the ordered list of chapter files. Every
`chapter-XX.json` file contains one chapter's identity, Gallery and Journey
styling, assembly placement data, rewards and 25 authored levels. Artwork files
remain separate binary assets; a future hosted catalog can add their download
locations without changing the gameplay model.

After editing any catalog file, run
`python3 Design/Campaign/format_catalog.py` with explicit paths to only the changed catalog files. Without paths the formatter processes the index
and every chapter file, keeping their structure readable while grouping
coordinate objects on bounded lines. It validates each formatted file before
replacing it.
