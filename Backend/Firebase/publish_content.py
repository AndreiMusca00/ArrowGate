#!/usr/bin/env python3
"""Publish prepared Pictarrow content to Google Cloud Storage.

This uses the existing Firebase CLI login on the developer machine. Package
objects are immutable and must use a new vN directory when they change. The
mutable master catalog is uploaded only after every referenced object succeeds.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


FIREBASE_CLIENT_ID = "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com"
FIREBASE_CLIENT_SECRET = "j9iVZfS8kkCEFUPaAeJV0sAi"
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
UPLOAD_ENDPOINT = "https://storage.googleapis.com/upload/storage/v1/b/{bucket}/o"


def request_json(request: urllib.request.Request) -> dict[str, Any]:
    context = ssl.create_default_context()
    try:
        import certifi  # type: ignore

        context = ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        pass
    try:
        with urllib.request.urlopen(request, timeout=120, context=context) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {error.code}: {detail}") from error


def access_token(token_file: Path) -> str:
    config = json.loads(token_file.read_text(encoding="utf-8"))
    refresh_token = config.get("tokens", {}).get("refresh_token")
    if not refresh_token:
        raise RuntimeError("Firebase CLI login is missing. Run `firebase login` first.")
    body = urllib.parse.urlencode(
        {
            "client_id": FIREBASE_CLIENT_ID,
            "client_secret": FIREBASE_CLIENT_SECRET,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        }
    ).encode("utf-8")
    response = request_json(
        urllib.request.Request(
            TOKEN_ENDPOINT,
            data=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            method="POST",
        )
    )
    token = response.get("access_token")
    if not token:
        raise RuntimeError("Google did not return an access token.")
    return token


def upload(source: Path, object_name: str, bucket: str, token: str) -> None:
    data = source.read_bytes()
    query = urllib.parse.urlencode({"uploadType": "media", "name": object_name})
    url = f"{UPLOAD_ENDPOINT.format(bucket=urllib.parse.quote(bucket, safe=''))}?{query}"
    content_type = mimetypes.guess_type(source.name)[0] or "application/octet-stream"
    result = request_json(
        urllib.request.Request(
            url,
            data=data,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": content_type,
                "Content-Length": str(len(data)),
            },
            method="POST",
        )
    )
    if int(result.get("size", -1)) != len(data) or result.get("name") != object_name:
        raise RuntimeError(f"Remote verification failed for {object_name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("content_root", type=Path, help="Output created by prepare_content.py")
    parser.add_argument("--bucket", required=True)
    parser.add_argument(
        "--token-file",
        type=Path,
        default=Path.home() / ".config" / "configstore" / "firebase-tools.json",
    )
    parser.add_argument(
        "--previous-catalog",
        type=Path,
        help="Upload only new immutable objects and reject changes to existing paths.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and print the publication plan without contacting Firebase.",
    )
    args = parser.parse_args()

    root = args.content_root.resolve()
    catalog_path = root / "catalog" / "catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    entries = [
        entry
        for package in [*catalog.get("chapters", []), *catalog.get("events", [])]
        for entry in package.get("files", [])
    ]
    if args.previous_catalog:
        previous = json.loads(args.previous_catalog.read_text(encoding="utf-8"))
        if int(catalog["contentVersion"]) <= int(previous["contentVersion"]):
            raise RuntimeError("The new contentVersion must be greater than the published catalog version.")
        previous_entries = {
            entry["remotePath"]: entry
            for package in [*previous.get("chapters", []), *previous.get("events", [])]
            for entry in package.get("files", [])
        }
        new_entries = []
        for entry in entries:
            old = previous_entries.get(entry["remotePath"])
            if old is None:
                new_entries.append(entry)
                continue
            unchanged = (
                old.get("sha256") == entry.get("sha256")
                and int(old.get("byteCount", -1)) == int(entry.get("byteCount", -2))
            )
            if not unchanged:
                raise RuntimeError(
                    f"Refusing to overwrite immutable object {entry['remotePath']}; bump its package version."
                )
        entries = new_entries
    if args.dry_run:
        for index, entry in enumerate(entries, start=1):
            print(f"[{index}/{len(entries)}] would upload {entry['remotePath']}")
        print(f"Would publish catalog version {catalog['contentVersion']} last.")
        return

    token = access_token(args.token_file.expanduser())

    for index, entry in enumerate(entries, start=1):
        remote_path = entry["remotePath"]
        source = root.joinpath(*Path(remote_path).parts)
        upload(source, remote_path, args.bucket, token)
        print(f"[{index}/{len(entries)}] {remote_path}")

    # Atomic publication point: clients learn about this release only now.
    upload(catalog_path, "catalog/catalog.json", args.bucket, token)
    print(f"Published catalog version {catalog['contentVersion']} after {len(entries)} package files.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Publish failed: {error}", file=sys.stderr)
        raise SystemExit(1)
