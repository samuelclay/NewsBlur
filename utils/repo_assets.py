#!/usr/bin/env python3
"""Heavy repository assets live in S3 instead of git (utils/repo_assets.py).

Store artwork (App Store and Play screenshots and preview videos) and performance recordings are gigabytes
of images and video, so those media files are gitignored inside the folders below; the text beside them
(metadata, scripts, audit notes) stays in git. Each folder has a manifest committed next to it,
<folder>.manifest.json, listing every media file's sha256 and size. The bytes are stored by content in
the private bucket s3://newsblur-repo-assets/objects/<sha256>, so identical files are stored once and every
manifest ever committed can still be pulled.

Run from the repository root (the Makefile wraps these in the NewsBlur Docker image):
    make assets-status   # what differs between your folders and the manifests
    make assets-pull     # download files the manifests list that you don't have
    make assets-push     # upload new or changed files and rewrite the manifests (then commit them)

Pass folder paths to limit any command to those folders, e.g. `repo_assets.py pull clients/store/artwork`.
Credentials come from AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY, else the deploy key file
/srv/secrets-newsblur/keys/aws.s3.token.
"""

import argparse
import configparser
import hashlib
import json
import os
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import boto3
from botocore.exceptions import ClientError

BUCKET = "newsblur-repo-assets"
ASSET_ROOTS = [
    "clients/store/artwork",
    "clients/android/Performance",
    "clients/ios/Performance",
]
CREDENTIALS_FILE = "/srv/secrets-newsblur/keys/aws.s3.token"
IGNORED_NAMES = {".DS_Store"}
# Only these file types move to S3; the matching patterns are in .gitignore.
MEDIA_EXTENSIONS = {".png", ".jpg", ".jpeg", ".mp4", ".mov", ".gif", ".webp"}
WORKERS = 16
CHUNK = 1024 * 1024


def s3_client():
    key = os.environ.get("AWS_ACCESS_KEY_ID")
    secret = os.environ.get("AWS_SECRET_ACCESS_KEY")
    if not key and os.path.exists(CREDENTIALS_FILE):
        parser = configparser.ConfigParser()
        parser.read(CREDENTIALS_FILE)
        key = parser.get("default", "aws_access_key_id", fallback=None)
        secret = parser.get("default", "aws_secret_access_key", fallback=None)
    return boto3.client("s3", aws_access_key_id=key, aws_secret_access_key=secret, region_name="us-east-1")


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(CHUNK), b""):
            digest.update(block)
    return digest.hexdigest()


def manifest_path(root):
    return Path(f"{root}.manifest.json")


def read_manifest(root):
    path = manifest_path(root)
    if not path.exists():
        return {}
    return json.loads(path.read_text())["files"]


def write_manifest(root, files):
    body = {
        "about": "Media files in this folder live in S3, not git. Run `make assets-pull` (utils/repo_assets.py).",
        "bucket": BUCKET,
        "files": {name: files[name] for name in sorted(files)},
    }
    manifest_path(root).write_text(json.dumps(body, indent=1, sort_keys=False) + "\n")


def local_files(root):
    base = Path(root)
    if not base.exists():
        return {}
    found = {}
    for path in base.rglob("*"):
        if path.is_file() and path.name not in IGNORED_NAMES and path.suffix.lower() in MEDIA_EXTENSIONS:
            found[path.relative_to(base).as_posix()] = path
    return found


def object_key(sha):
    return f"objects/{sha}"


def existing_objects(client):
    keys = set()
    for page in client.get_paginator("list_objects_v2").paginate(Bucket=BUCKET, Prefix="objects/"):
        for item in page.get("Contents", []):
            keys.add(item["Key"].split("/", 1)[1])
    return keys


def describe(root, files):
    total = sum(entry["size"] for entry in files.values())
    return f"{root}: {len(files)} files, {total / 1e9:.2f} GB"


def status(roots):
    clean = True
    for root in roots:
        manifest = read_manifest(root)
        on_disk = local_files(root)
        missing = [name for name in manifest if name not in on_disk]
        untracked = [name for name in on_disk if name not in manifest]
        changed = [
            name
            for name, path in on_disk.items()
            if name in manifest
            and (path.stat().st_size != manifest[name]["size"] or sha256_of(path) != manifest[name]["sha256"])
        ]
        print(describe(root, manifest))
        for label, names in (("not downloaded", missing), ("new, not pushed", untracked), ("changed", changed)):
            if names:
                clean = False
                print(f"  {len(names)} {label}: {', '.join(sorted(names)[:5])}{' ...' if len(names) > 5 else ''}")
    return clean


def pull(roots):
    client = s3_client()

    def fetch(job):
        root, name, entry = job
        target = Path(root) / name
        if target.exists() and target.stat().st_size == entry["size"] and sha256_of(target) == entry["sha256"]:
            return 0
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as handle:
            client.download_fileobj(BUCKET, object_key(entry["sha256"]), handle)
        if sha256_of(handle.name) != entry["sha256"]:
            os.unlink(handle.name)
            raise RuntimeError(f"Checksum mismatch downloading {target}")
        os.replace(handle.name, target)
        return 1

    jobs = [(root, name, entry) for root in roots for name, entry in read_manifest(root).items()]
    with ThreadPoolExecutor(WORKERS) as pool:
        downloaded = sum(pool.map(fetch, jobs))
    print(f"Downloaded {downloaded} of {len(jobs)} files ({len(jobs) - downloaded} already up to date)")


def push(roots):
    client = s3_client()
    stored = existing_objects(client)
    for root in roots:
        on_disk = local_files(root)
        with ThreadPoolExecutor(WORKERS) as pool:
            hashes = dict(zip(on_disk, pool.map(sha256_of, on_disk.values())))
        files = {name: {"sha256": hashes[name], "size": path.stat().st_size} for name, path in on_disk.items()}
        uploads = {}
        for name, entry in files.items():
            if entry["sha256"] not in stored:
                uploads[entry["sha256"]] = on_disk[name]

        def upload(item):
            sha, path = item
            client.upload_file(str(path), BUCKET, object_key(sha))
            return sha

        with ThreadPoolExecutor(WORKERS) as pool:
            stored.update(pool.map(upload, uploads.items()))
        previous = read_manifest(root)
        write_manifest(root, files)
        added = len(set(files) - set(previous))
        removed = len(set(previous) - set(files))
        changed = sum(1 for name in files if name in previous and previous[name] != files[name])
        print(f"{describe(root, files)}; uploaded {len(uploads)} new objects; {added} added, {changed} changed, "
              f"{removed} removed in {manifest_path(root)}")


def verify(roots):
    """Confirm every object the manifests reference exists in S3 with the right size."""
    client = s3_client()
    problems = 0
    for root in roots:
        for name, entry in read_manifest(root).items():
            try:
                head = client.head_object(Bucket=BUCKET, Key=object_key(entry["sha256"]))
            except ClientError:
                print(f"missing in S3: {root}/{name}")
                problems += 1
                continue
            if head["ContentLength"] != entry["size"]:
                print(f"size mismatch in S3: {root}/{name}")
                problems += 1
        print(f"verified {describe(root, read_manifest(root))}")
    return problems == 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["status", "pull", "push", "verify"])
    parser.add_argument("roots", nargs="*", help="limit to these asset folders")
    args = parser.parse_args()
    roots = args.roots or ASSET_ROOTS
    unknown = [root for root in roots if root not in ASSET_ROOTS]
    if unknown:
        sys.exit(f"Not an asset folder: {', '.join(unknown)} (known: {', '.join(ASSET_ROOTS)})")
    if args.command == "status":
        status(roots)
        return
    if args.command == "verify":
        sys.exit(0 if verify(roots) else 1)
    {"pull": pull, "push": push}[args.command](roots)


if __name__ == "__main__":
    main()
