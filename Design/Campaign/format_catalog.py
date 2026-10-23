#!/usr/bin/env python3
"""Format catalog.json for humans without overwhelming Xcode.

The catalog keeps chapters, levels and arrows on separate lines, while dense
coordinate arrays are packed into short lines. The output remains ordinary
JSON and does not change any catalog values.
"""

from __future__ import annotations

import argparse
import json
import os
import tempfile
from pathlib import Path
from typing import Any


DEFAULT_CATALOG_DIRECTORY = Path(__file__).resolve().parents[2] / "Backend/ContentSource/Levels"
INDENT = 2
MAX_LINE_LENGTH = 150


def compact_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def is_scalar(value: Any) -> bool:
    return value is None or isinstance(value, (str, int, float, bool))


def contains_list(value: Any) -> bool:
    if isinstance(value, list):
        return True
    if isinstance(value, dict):
        return any(contains_list(child) for child in value.values())
    return False


def is_compact_object(value: Any) -> bool:
    """Coordinates and similar leaf objects are safe to keep on one line."""
    if not isinstance(value, dict):
        return False
    return not contains_list(value) and len(compact_json(value)) <= 100


def packed_array(values: list[Any], depth: int, max_width: int) -> list[str]:
    indentation = " " * (depth * INDENT)
    item_indentation = " " * ((depth + 1) * INDENT)
    tokens = [compact_json(value) for value in values]
    lines = [indentation + "["]
    chunks: list[str] = []
    current = ""

    for token in tokens:
        candidate = token if not current else f"{current}, {token}"
        # Reserve one character for a comma when another packed line follows.
        if current and len(item_indentation) + len(candidate) + 1 > max_width:
            chunks.append(current)
            current = token
        else:
            current = candidate
    if current:
        chunks.append(current)

    for index, chunk in enumerate(chunks):
        comma = "," if index < len(chunks) - 1 else ""
        lines.append(f"{item_indentation}{chunk}{comma}")
    lines.append(indentation + "]")
    return lines


def format_value(value: Any, depth: int = 0, max_width: int = MAX_LINE_LENGTH) -> list[str]:
    indentation = " " * (depth * INDENT)

    if is_scalar(value):
        return [indentation + compact_json(value)]

    if isinstance(value, list):
        if not value:
            return [indentation + "[]"]
        if all(is_scalar(item) or is_compact_object(item) for item in value):
            inline = compact_json(value)
            if len(indentation) + len(inline) <= max_width:
                return [indentation + inline]
            return packed_array(value, depth, max_width)

        lines = [indentation + "["]
        for index, item in enumerate(value):
            child_lines = format_value(item, depth + 1, max_width)
            if index < len(value) - 1:
                child_lines[-1] += ","
            lines.extend(child_lines)
        lines.append(indentation + "]")
        return lines

    if isinstance(value, dict):
        if not value:
            return [indentation + "{}"]
        lines = [indentation + "{"]
        items = list(value.items())
        for index, (key, child) in enumerate(items):
            key_prefix = " " * ((depth + 1) * INDENT) + json.dumps(key) + ": "
            if is_scalar(child) or is_compact_object(child):
                child_lines = [" " * ((depth + 1) * INDENT) + compact_json(child)]
            else:
                child_lines = format_value(child, depth + 1, max_width)
            child_lines[0] = key_prefix + child_lines[0].lstrip()
            if index < len(items) - 1:
                child_lines[-1] += ","
            lines.extend(child_lines)
        lines.append(indentation + "}")
        return lines

    raise TypeError(f"Unsupported JSON value: {type(value).__name__}")


def format_catalog(path: Path, max_width: int) -> None:
    original = json.loads(path.read_text(encoding="utf-8"))
    formatted = "\n".join(format_value(original, max_width=max_width)) + "\n"

    # Parse the result before replacing the source file. This catches formatter
    # regressions while guaranteeing the in-memory data is unchanged.
    if json.loads(formatted) != original:
        raise RuntimeError("Formatted catalog does not match the original data")

    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    try:
        with os.fdopen(file_descriptor, "w", encoding="utf-8") as temporary_file:
            temporary_file.write(formatted)
        os.replace(temporary_name, path)
    except BaseException:
        Path(temporary_name).unlink(missing_ok=True)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalogs", nargs="*", type=Path)
    parser.add_argument("--max-width", type=int, default=MAX_LINE_LENGTH)
    arguments = parser.parse_args()

    paths = arguments.catalogs or sorted(DEFAULT_CATALOG_DIRECTORY.glob("*.json"))
    for path in paths:
        format_catalog(path.resolve(), arguments.max_width)


if __name__ == "__main__":
    main()
