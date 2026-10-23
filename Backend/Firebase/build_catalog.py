#!/usr/bin/env python3
"""Fill byteCount and sha256 from a directory that mirrors Firebase Storage."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath


def safe_remote_path(value: str) -> PurePosixPath:
    path = PurePosixPath(value)
    if path.is_absolute() or not value or any(part in {"", ".", ".."} for part in path.parts):
        raise ValueError(f"Unsafe remotePath: {value!r}")
    return path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("draft", type=Path, help="Draft catalog JSON")
    parser.add_argument("content_root", type=Path, help="Folder mirroring the Storage bucket")
    parser.add_argument("output", type=Path, help="Validated catalog to upload")
    args = parser.parse_args()

    catalog = json.loads(args.draft.read_text(encoding="utf-8"))
    seen: set[str] = set()
    packages = [*catalog.get("chapters", []), *catalog.get("events", [])]
    for package in packages:
        for entry in package.get("files", []):
            remote = str(safe_remote_path(entry["remotePath"]))
            if remote in seen:
                raise ValueError(f"Duplicate remotePath: {remote}")
            seen.add(remote)
            source = args.content_root.joinpath(*PurePosixPath(remote).parts)
            if not source.is_file():
                raise FileNotFoundError(source)
            data = source.read_bytes()
            entry["byteCount"] = len(data)
            entry["sha256"] = hashlib.sha256(data).hexdigest()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
