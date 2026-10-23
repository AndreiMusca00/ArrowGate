#!/usr/bin/env python3
"""Package the checked-in campaign and event content for Firebase Storage.

The generated directory mirrors the bucket. Upload every chapter/event object
first and ``catalog/catalog.json`` last so clients never observe a partial
release.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path
from typing import Any


IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def version_overrides(values: list[str], label: str) -> dict[str, int]:
    result: dict[str, int] = {}
    for value in values:
        identifier, separator, version = value.partition("=")
        if not separator or not identifier or not version.isdigit() or int(version) < 1:
            raise ValueError(f"{label} versions must use ID=VERSION, received {value!r}")
        result[identifier] = int(version)
    return result


def file_entry(
    source: Path,
    destination: Path,
    output_root: Path,
    retention: str,
    asset_name: str | None = None,
) -> dict[str, Any]:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.resolve() != destination.resolve():
        shutil.copy2(source, destination)
    data = destination.read_bytes()
    relative = destination.relative_to(output_root).as_posix()
    relative_parts = destination.relative_to(output_root).parts
    local_path = Path(*relative_parts[3:]).as_posix()
    return {
        "remotePath": relative,
        "localPath": local_path,
        "sha256": hashlib.sha256(data).hexdigest(),
        "byteCount": len(data),
        "retention": retention,
        "assetName": asset_name,
    }


def build_asset_index(asset_root: Path) -> dict[str, Path]:
    result: dict[str, Path] = {}
    for path in asset_root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in IMAGE_SUFFIXES:
            continue
        if path.stem in result:
            raise ValueError(f"Duplicate asset name {path.stem}: {result[path.stem]} and {path}")
        result[path.stem] = path
    return result


def artwork_names(levels: list[dict[str, Any]]) -> list[str]:
    names: list[str] = []
    for entry in levels:
        level = entry.get("level", entry)
        name = level.get("completionArtwork")
        if name and name not in names:
            names.append(name)
    return names


def package_chapter(
    source: Path,
    data: dict[str, Any],
    asset_index: dict[str, Path],
    output_root: Path,
    version: int,
) -> dict[str, Any]:
    chapter = data["chapter"]
    chapter_id = int(chapter["id"])
    root = output_root / "chapters" / f"chapter-{chapter_id}" / f"v{version}"
    metadata = root / "chapter.json"
    write_json(metadata, data)
    files = [file_entry(metadata, metadata, output_root, "metadata")]

    final_name = chapter["assembly"]["finalArtwork"]
    for name in artwork_names(data["levels"]):
        source_asset = asset_index.get(name)
        if source_asset is None:
            raise FileNotFoundError(f"{source}: missing asset {name}")
        retention = "reward" if name == final_name else "gameplay"
        destination = root / "artwork" / f"{name}{source_asset.suffix.lower()}"
        files.append(file_entry(source_asset, destination, output_root, retention, name))

    if final_name not in {entry["assetName"] for entry in files if entry["assetName"]}:
        source_asset = asset_index.get(final_name)
        if source_asset is None:
            raise FileNotFoundError(f"{source}: missing final asset {final_name}")
        destination = root / "artwork" / f"{final_name}{source_asset.suffix.lower()}"
        files.append(file_entry(source_asset, destination, output_root, "reward", final_name))

    levels = data["levels"]
    first_level = min(int(level["id"]) for level in levels)
    return {
        "chapterID": chapter_id,
        "version": version,
        "firstLevel": first_level,
        "levelCount": len(levels),
        "files": files,
    }


def package_event(
    source: Path,
    data: dict[str, Any],
    asset_index: dict[str, Path],
    output_root: Path,
    version: int,
) -> dict[str, Any]:
    event = data["event"]
    event_id = event["id"]
    root = output_root / "events" / event_id / f"v{version}"
    metadata = root / "event.json"
    write_json(metadata, data)
    files = [file_entry(metadata, metadata, output_root, "metadata")]

    final_name = event.get("reward", {}).get("assetName")
    for name in artwork_names(data.get("levels", [])):
        source_asset = asset_index.get(name)
        if source_asset is None:
            raise FileNotFoundError(f"{source}: missing asset {name}")
        retention = "reward" if name == final_name else "gameplay"
        destination = root / "artwork" / f"{name}{source_asset.suffix.lower()}"
        files.append(file_entry(source_asset, destination, output_root, retention, name))

    if final_name and final_name not in {entry["assetName"] for entry in files if entry["assetName"]}:
        source_asset = asset_index.get(final_name)
        if source_asset is None:
            raise FileNotFoundError(f"{source}: missing final asset {final_name}")
        destination = root / "artwork" / f"{final_name}{source_asset.suffix.lower()}"
        files.append(file_entry(source_asset, destination, output_root, "reward", final_name))

    schedule = event["schedule"]
    return {
        "eventID": event_id,
        "version": version,
        "previewStartsAt": schedule.get("previewStartsAt", schedule["startsAt"]),
        "startsAt": schedule["startsAt"],
        "endsAt": schedule.get("endsAt"),
        "retainRewardAfterEnd": bool(final_name),
        "files": files,
    }


def main() -> None:
    project_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=project_root)
    parser.add_argument(
        "--level-root",
        type=Path,
        help="Catalog source directory; defaults to Backend/ContentSource/Levels",
    )
    parser.add_argument(
        "--asset-root",
        type=Path,
        help="Artwork source directory; defaults to Backend/ContentSource/Artwork",
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--content-version", type=int)
    parser.add_argument("--package-version", type=int, default=1)
    parser.add_argument(
        "--chapter-version",
        action="append",
        default=[],
        metavar="ID=VERSION",
        help="Override one chapter package version without changing other packages.",
    )
    parser.add_argument(
        "--event-version",
        action="append",
        default=[],
        metavar="ID=VERSION",
        help="Override one event package version without changing other packages.",
    )
    parser.add_argument("--minimum-app-version", default="1.0")
    args = parser.parse_args()

    root = args.project_root.resolve()
    level_root = (args.level_root or root / "Backend" / "ContentSource" / "Levels").resolve()
    asset_root = (args.asset_root or root / "Backend" / "ContentSource" / "Artwork").resolve()
    output_root = args.output.resolve()
    if output_root.exists():
        shutil.rmtree(output_root)
    output_root.mkdir(parents=True)

    index = read_json(level_root / "catalog.json")
    content_version = args.content_version or int(index["version"])
    assets = build_asset_index(asset_root)
    chapter_versions = version_overrides(args.chapter_version, "Chapter")
    event_versions = version_overrides(args.event_version, "Event")
    chapters = []
    for filename in index["chapterFiles"]:
        source = level_root / filename
        data = read_json(source)
        chapter_id = str(data["chapter"]["id"])
        chapters.append(package_chapter(
            source, data, assets, output_root,
            chapter_versions.get(chapter_id, args.package_version),
        ))
    events = []
    for filename in index.get("eventFiles", []):
        source = level_root / filename
        data = read_json(source)
        event_id = str(data["event"]["id"])
        events.append(package_event(
            source, data, assets, output_root,
            event_versions.get(event_id, args.package_version),
        ))
    catalog = {
        "schemaVersion": 1,
        "contentVersion": content_version,
        "minimumAppVersion": args.minimum_app_version,
        "configuration": index["configuration"],
        "chapters": chapters,
        "events": events,
    }
    write_json(output_root / "catalog" / "catalog.json", catalog)

    file_count = sum(len(package["files"]) for package in [*chapters, *events])
    total_bytes = sum(path.stat().st_size for path in output_root.rglob("*") if path.is_file())
    print(
        f"Prepared {len(chapters)} chapters, {len(events)} events, "
        f"{file_count} package files ({total_bytes / 1_048_576:.1f} MiB) at {output_root}"
    )


if __name__ == "__main__":
    main()
