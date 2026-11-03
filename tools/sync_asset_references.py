#!/usr/bin/env python3
"""Keep Git-visible image references outside Flutter's asset bundle.

Without --download this lists the local manifest only and never uses the network.
Download URLs stay in the ignored source list, not the tracked manifest.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import unquote, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener


WORKSPACE = Path(__file__).resolve().parents[1]
REFERENCE_ROOT = WORKSPACE / "assets" / "reference"
MANIFEST = REFERENCE_ROOT / "manifest.json"
MAX_IMAGE_BYTES = 10 * 1024 * 1024
MAX_FETCH_SECONDS = 120


class ReferenceError(Exception):
    """A message safe to display without exposing a download token."""


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise ReferenceError("Could not read the JSON input.") from error


def load_manifest():
    if not MANIFEST.exists():
        return {}
    value = read_json(MANIFEST)
    if (
        not isinstance(value, dict)
        or value.get("schema") != 1
        or not isinstance(value.get("assets"), list)
        or any(not isinstance(row, dict) or "key" not in row for row in value["assets"])
    ):
        raise ReferenceError("Unsupported local reference manifest.")
    rows = {row["key"]: row for row in value["assets"]}
    if len(rows) != len(value["assets"]):
        raise ReferenceError("Duplicate keys in local reference manifest.")
    return rows


def source_object(url, prefix):
    if not isinstance(url, str) or not url:
        raise ReferenceError("A complete image download URL is missing.")
    try:
        parsed = urlsplit(url)
        match = re.fullmatch(r"/v0/b/([^/]+)/o/(.+)", parsed.path)
        if (
            parsed.scheme != "https"
            or parsed.netloc != "firebasestorage.googleapis.com"
            or parsed.fragment
            or not match
        ):
            raise ReferenceError("Expected a Firebase Storage HTTPS object URL.")
        bucket = unquote(match[1], errors="strict")
        name = unquote(match[2], errors="strict")
    except (ValueError, UnicodeError) as error:
        raise ReferenceError("Invalid encoded image object path.") from error
    if not name.startswith(prefix):
        raise ReferenceError("Image object is outside the configured remote prefix.")
    relative = name[len(prefix) :]
    parts = relative.split("/")
    if any(
        not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", part)
        or part in (".", "..")
        for part in parts
    ):
        raise ReferenceError("Unsafe reference filename.")
    suffix = Path(relative).suffix.lower()
    if suffix not in (".png", ".webp", ".jpg", ".jpeg"):
        raise ReferenceError("Only PNG, WebP, and JPEG references are supported here.")
    return relative, {"provider": "firebase-storage", "bucket": bucket, "object": name}


def image_format(header):
    if header.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if header.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if header[:4] == b"RIFF" and header[8:12] == b"WEBP":
        return "image/webp"
    raise ReferenceError("Downloaded response is not a recognized image file.")


def destination(relative):
    path = REFERENCE_ROOT / relative
    for parent in (REFERENCE_ROOT, *path.parents):
        if parent == WORKSPACE:
            break
        if parent.is_symlink():
            raise ReferenceError("Reference directories must not be symlinks.")
    if path.is_symlink():
        raise ReferenceError("Reference files must not be symlinks.")
    return path


def file_digest(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(64 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    pending = path.with_name(path.name + ".download")
    if pending.is_symlink():
        raise ReferenceError("Temporary reference files must not be symlinks.")
    digest = hashlib.sha256()
    total = 0
    header = b""
    started = time.monotonic()
    try:
        request = Request(url, headers={"Accept-Encoding": "identity"})
        with build_opener(NoRedirect()).open(request, timeout=20) as response:
            if response.status != 200:
                raise ReferenceError("Image server did not return HTTP 200.")
            with pending.open("wb") as output:
                while True:
                    chunk = response.read(64 * 1024)
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > MAX_IMAGE_BYTES:
                        raise ReferenceError("Image exceeds the 10 MiB reference limit.")
                    if time.monotonic() - started > MAX_FETCH_SECONDS:
                        raise ReferenceError("Image download exceeded its time limit.")
                    header = (header + chunk)[:16]
                    digest.update(chunk)
                    output.write(chunk)
                output.flush()
                os.fsync(output.fileno())
        media_type = image_format(header)
        expected = {
            ".png": "image/png",
            ".webp": "image/webp",
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
        }[path.suffix.lower()]
        if media_type != expected:
            raise ReferenceError("Image bytes do not match the remote file extension.")
        os.replace(pending, path)
        return {"bytes": total, "sha256": digest.hexdigest(), "media_type": media_type}
    finally:
        if pending.exists():
            pending.unlink()


def save_manifest(rows):
    REFERENCE_ROOT.mkdir(parents=True, exist_ok=True)
    temporary = REFERENCE_ROOT / "manifest.json.download"
    if MANIFEST.is_symlink() or temporary.is_symlink():
        raise ReferenceError("Reference manifests must not be symlinks.")
    value = {"schema": 1, "assets": [rows[key] for key in sorted(rows)]}
    with temporary.open("w", encoding="utf-8") as output:
        output.write(json.dumps(value, indent=2, ensure_ascii=False) + "\n")
        output.flush()
        os.fsync(output.fileno())
    os.replace(temporary, MANIFEST)


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        default=WORKSPACE / "redkeep" / "onboarding-downloads.local.json",
    )
    parser.add_argument("--prefix", default="redkeep/assets/")
    parser.add_argument("--download", action="store_true", help="Fetch missing/changed inputs.")
    parser.add_argument(
        "--refresh", action="store_true", help="With --download, re-fetch all supplied images."
    )
    args = parser.parse_args()
    if args.refresh and not args.download:
        parser.error("--refresh requires --download")
    rows = load_manifest()
    if not args.download:
        for key, row in sorted(rows.items()):
            print(f"{key}: assets/reference/{row['path']}")
        print(f"{len(rows)} local references. No network requests made.")
        return 0
    urls = read_json(args.source)
    if not isinstance(urls, dict) or not urls:
        raise ReferenceError("Expected a nonempty object mapping asset keys to URLs.")
    if not args.prefix or not args.prefix.endswith("/"):
        raise ReferenceError("The remote prefix must end in '/'.")
    failures = 0
    seen = set()
    for key, url in urls.items():
        safe_key = key if isinstance(key, str) and re.fullmatch(
            r"[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)+", key
        ) else "invalid-key"
        try:
            if safe_key == "invalid-key":
                raise ReferenceError("Invalid asset key.")
            relative, remote = source_object(url, args.prefix)
            if relative in seen:
                raise ReferenceError("Duplicate reference destination in source list.")
            seen.add(relative)
            path = destination(relative)
            previous = rows.get(key, {})
            if (
                not args.refresh
                and previous.get("path") == relative
                and previous.get("remote") == remote
                and path.is_file()
                and path.stat().st_size == previous.get("bytes")
                and file_digest(path) == previous.get("sha256")
            ):
                print(f"Kept {safe_key}: assets/reference/{relative}", flush=True)
                continue
            details = download(url, path)
            rows[key] = {"key": key, "path": relative, "remote": remote, **details}
            save_manifest(rows)
            print(f"Saved {safe_key}: assets/reference/{relative} ({details['bytes']} bytes)", flush=True)
        except HTTPError as error:
            failures += 1
            print(f"{safe_key}: HTTP {error.code}; URL omitted.", file=sys.stderr, flush=True)
        except ReferenceError as error:
            failures += 1
            print(f"{safe_key}: {error}", file=sys.stderr, flush=True)
        except (URLError, OSError, ValueError):
            failures += 1
            print(f"{safe_key}: download or local storage failed; URL omitted.", file=sys.stderr, flush=True)
    print(f"{len(rows)} references recorded; {failures} failed inputs.", flush=True)
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        sys.exit(run())
    except ReferenceError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
