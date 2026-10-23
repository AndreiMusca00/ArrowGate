#!/usr/bin/env python3
"""Validate and publish the finished artwork for Chapter 1.

This tool deliberately does not create puzzles and never edits catalog.json.
The full illustration and its 24 semantic transparent objects are authored
first; playable levels are authored and validated in a separate workflow.
"""
from __future__ import annotations

import json
import shutil
import tempfile
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
DESIGN_ROOT = ROOT / "Design" / "Campaign"
CONTENT_ARTWORK = ROOT / "Backend" / "ContentSource" / "Artwork"
DESTINATION = CONTENT_ARTWORK / "Chapter 1"
COMPLETE_SOURCE = DESIGN_ROOT / "treehouse-3d-concept.png"
PIECES_SOURCE = DESIGN_ROOT / "treehouse-3d-pieces"
ASSET_PREFIX = "EnchantedTree"
PIECE_COUNT = 24


def validated_image(path: Path) -> Image.Image:
    if not path.is_file():
        raise FileNotFoundError(f"Missing artwork source: {path}")
    image = Image.open(path).convert("RGBA")
    if image.width < 2 or image.height < 2 or image.getchannel("A").getbbox() is None:
        raise ValueError(f"Artwork has no visible pixels: {path}")
    return image


def write_imageset(root: Path, name: str, image: Image.Image) -> None:
    imageset = root / f"{name}.imageset"
    imageset.mkdir(parents=True)
    filename = f"{name}.png"
    image.save(imageset / filename, optimize=True)
    (imageset / "Contents.json").write_text(
        json.dumps(
            {
                "images": [
                    {"filename": filename, "idiom": "universal", "scale": "1x"}
                ],
                "info": {"author": "xcode", "version": 1},
            },
            indent=2,
        )
        + "\n"
    )


def build_staged_group(staging: Path) -> None:
    staging.mkdir(parents=True)
    (staging / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )

    write_imageset(staging, f"{ASSET_PREFIX}Complete", validated_image(COMPLETE_SOURCE))
    for position in range(1, PIECE_COUNT + 1):
        source = PIECES_SOURCE / f"piece-{position:02d}.png"
        write_imageset(
            staging,
            f"{ASSET_PREFIX}Piece{position:02d}",
            validated_image(source),
        )


def publish_group() -> None:
    staging_parent = Path(
        tempfile.mkdtemp(prefix=".chapter-artwork-", dir=CONTENT_ARTWORK)
    )
    staging = staging_parent / DESTINATION.name
    backup = CONTENT_ARTWORK / f".{DESTINATION.name}.previous"
    moved_existing = False

    try:
        build_staged_group(staging)
        if backup.exists():
            shutil.rmtree(backup)
        if DESTINATION.exists():
            DESTINATION.rename(backup)
            moved_existing = True
        try:
            staging.rename(DESTINATION)
        except Exception:
            if moved_existing and backup.exists() and not DESTINATION.exists():
                backup.rename(DESTINATION)
            raise
        if backup.exists():
            shutil.rmtree(backup)
    finally:
        if staging_parent.exists():
            shutil.rmtree(staging_parent)


if __name__ == "__main__":
    publish_group()
    print(
        f"Published {PIECE_COUNT} semantic pieces and one complete illustration. "
        "catalog.json was not modified."
    )
