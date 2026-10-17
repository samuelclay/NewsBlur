#!/usr/bin/env python3
"""Stage reviewed Play graphics in an explicit edit; never create or commit edits.

Run google_play_assets.py in the NewsBlur Docker container. Snapshot before any
changes, then stage with a durable checkpoint. A new post-commit edit can be used
with verify to prove the saved graphics. Console alt text is separate: Google's
Images API exposes no alt-text field.
"""

import argparse
import hashlib
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from google_play import PACKAGE, ROOT, indexed, read_json, service, write_json

IMAGE_TYPES = (
    "phoneScreenshots",
    "sevenInchScreenshots",
    "tenInchScreenshots",
    "tvScreenshots",
    "wearScreenshots",
    "icon",
    "featureGraphic",
    "tvBanner",
)
TARGET_TYPES = {"phoneScreenshots", "sevenInchScreenshots", "tenInchScreenshots", "icon", "featureGraphic"}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def atomic_json(path, value):
    # google_play_assets.py checkpoints survive interruption between operations.
    path = Path(path)
    temporary = path.with_name(path.name + ".tmp")
    write_json(temporary, value)
    os.replace(temporary, path)


def load_manifest(path):
    path = Path(path).resolve()
    manifest = read_json(path)
    if manifest.get("packageName") != PACKAGE:
        raise ValueError("Manifest package must be com.newsblur")
    mappings = {
        row["language"]: row["google"] for row in read_json(ROOT / "clients/store/locales.json")["locales"]
    }
    if set(mappings) != set(read_json(ROOT / "localization/languages.json")):
        raise ValueError("Locale mappings differ from app languages")
    groups = {}
    for row in manifest["assets"]:
        if row.get("visual_review") != "approved":
            raise ValueError("Every exported asset must have an approved visual review")
        if mappings.get(row["language"]) != row["locale"] or row["imageType"] not in TARGET_TYPES:
            raise ValueError("Unknown language, locale, or target image type")
        if not isinstance(row["position"], int) or row["position"] < 1:
            raise ValueError("Positions must be positive integers")
        filename = (path.parent / row["path"]).resolve()
        data = filename.read_bytes()
        if hashlib.sha256(data).hexdigest() != row["sha256"]:
            raise ValueError(f"Source checksum mismatch: {filename}")
        if not 0 < len(data) <= 15 * 1024 * 1024:
            raise ValueError(f"Image exceeds API size limit: {filename}")
        from PIL import Image

        with Image.open(filename) as image:
            width, height = image.size
            kind = row["imageType"]
            if image.format not in {"PNG", "JPEG"}:
                raise ValueError(f"Unsupported image format: {filename}")
            if kind == "icon":
                valid = (
                    image.format == "PNG"
                    and image.mode == "RGBA"
                    and (width, height) == (512, 512)
                    and len(data) <= 1024 * 1024
                )
            else:
                valid = image.mode == "RGB"
                if kind == "featureGraphic":
                    valid = valid and (width, height) == (1024, 500)
                elif kind == "phoneScreenshots":
                    valid = valid and (width, height) == (1080, 1920)
                else:
                    # Google recommends 16:9, but accepts native tablets up to 2:1.
                    valid = valid and min(width, height) >= 320 and max(width, height) <= 3840
                    valid = valid and max(width, height) <= 2 * min(width, height)
            if not valid:
                raise ValueError(f"Image does not match this refresh's reviewed format: {filename}")
            mimetype = "image/png" if image.format == "PNG" else "image/jpeg"
        key = row["locale"] + "/" + kind
        groups.setdefault(key, []).append({**row, "file": str(filename), "mimetype": mimetype})
    expected = {locale + "/" + kind for locale in mappings.values() for kind in TARGET_TYPES}
    if set(groups) != expected:
        raise ValueError("Manifest must cover all 21 locales and all five target image types")
    for key, rows in groups.items():
        rows.sort(key=lambda row: row["position"])
        count = 1 if key.split("/")[1] in {"icon", "featureGraphic"} else 4
        if [row["position"] for row in rows] != list(range(1, count + 1)):
            raise ValueError(f"Missing or duplicate ordered positions: {key}")
    videos = indexed(manifest.get("videos", []), "locale")
    for locale, row in videos.items():
        parsed = urlparse(row["url"])
        valid = parsed.scheme == "https" and not parsed.fragment and not parsed.username
        if parsed.netloc == "www.youtube.com":
            params = parse_qs(parsed.query)
            valid = valid and parsed.path == "/watch" and set(params) == {"v"} and len(params["v"]) == 1
            video_id = params.get("v", [""])[0]
        elif parsed.netloc == "youtu.be":
            valid = valid and not parsed.query
            video_id = parsed.path[1:]
        else:
            valid, video_id = False, ""
        if locale not in mappings.values() or not valid or not re.fullmatch(r"[\w-]{11}", video_id, re.ASCII):
            raise ValueError(f"Invalid localized YouTube URL: {locale}")
    return manifest, groups, videos


def image_list(api, edit_id, key):
    locale, kind = key.split("/")
    return (
        api.edits()
        .images()
        .list(packageName=PACKAGE, editId=edit_id, language=locale, imageType=kind)
        .execute()
        .get("images", [])
    )


def hashes(images):
    return [image["sha256"].lower() for image in images]


def identities(images):
    return [(image["id"], image["sha256"].lower()) for image in images]


def snapshot(api, edit_id):
    edit = api.edits().get(packageName=PACKAGE, editId=edit_id).execute()
    listings = api.edits().listings().list(packageName=PACKAGE, editId=edit_id).execute().get("listings", [])
    images = {}
    for listing in listings:
        for kind in IMAGE_TYPES:
            key = listing["language"] + "/" + kind
            images[key] = image_list(api, edit_id, key)
    return {
        "packageName": PACKAGE,
        "capturedAt": datetime.now(timezone.utc).isoformat(),
        "edit": edit,
        "listings": listings,
        "images": images,
        "tracks": api.edits().tracks().list(packageName=PACKAGE, editId=edit_id).execute().get("tracks", []),
        "details": api.edits().details().get(packageName=PACKAGE, editId=edit_id).execute(),
    }


def assert_preserved(actual, baseline, groups, videos, *, final=False):
    if actual["packageName"] != PACKAGE or baseline["packageName"] != PACKAGE:
        raise ValueError("Wrong package in snapshot")
    for field in ("tracks", "details"):
        if actual[field] != baseline[field]:
            raise ValueError(f"Unrelated {field} changed")
    previous = indexed(baseline["listings"], "language")
    current = indexed(actual["listings"], "language")
    if set(previous) != set(current):
        raise ValueError("Listing locale inventory changed")
    for locale, before in previous.items():
        allowed = [before]
        if locale in videos:
            desired = {**before, "video": videos[locale]["url"]}
            allowed = [desired] if final else [before, desired]
        if current[locale] not in allowed:
            raise ValueError(f"Unrelated listing text changed: {locale}")
    if set(actual["images"]) != set(baseline["images"]):
        raise ValueError("Image group inventory changed")
    for key, images in baseline["images"].items():
        if key not in groups and identities(actual["images"][key]) != identities(images):
            raise ValueError(f"Unrelated image group changed: {key}")
    if not set(groups) <= set(baseline["images"]):
        raise ValueError("Create missing listing locales before the asset snapshot")


def verify(api, edit_id, baseline, groups, videos):
    current = snapshot(api, edit_id)
    assert_preserved(current, baseline, groups, videos, final=True)
    for key, rows in groups.items():
        if hashes(current["images"][key]) != [row["sha256"] for row in rows]:
            raise ValueError(f"Image count, order or checksum mismatch: {key}")
    return {
        "groups": len(groups),
        "images": sum(map(len, groups.values())),
        "videos": len(videos),
        "editId": edit_id,
    }


def stage_group(api, edit_id, key, rows, baseline_images, checkpoint, save, upload):
    desired = [row["sha256"] for row in rows]
    current = image_list(api, edit_id, key)
    state = checkpoint["groups"].get(key)
    if hashes(current) == desired:
        checkpoint["groups"][key] = "verified"
        save()
        return
    if state is None:
        if identities(current) != identities(baseline_images):
            raise ValueError(f"Image group changed since baseline: {key}")
        checkpoint["groups"][key] = "clearing"
        save()
        state = "clearing"
    if state == "clearing":
        if current:
            if identities(current) != identities(baseline_images):
                raise ValueError(f"Unexpected images during clear recovery: {key}")
            locale, kind = key.split("/")
            api.edits().images().deleteall(
                packageName=PACKAGE, editId=edit_id, language=locale, imageType=kind
            ).execute()
        if image_list(api, edit_id, key):
            raise ValueError(f"Deletion did not clear target group: {key}")
        checkpoint["groups"][key] = "uploading"
        save()
    elif state != "uploading":
        raise ValueError(f"Previously verified image group changed: {key}")
    current = image_list(api, edit_id, key)
    if hashes(current) != desired[: len(current)] or len(current) > len(rows):
        raise ValueError(f"Unexpected upload prefix: {key}")
    for row in rows[len(current) :]:
        upload(api, edit_id, key, row)
        current = image_list(api, edit_id, key)
        expected_count = row["position"]
        if hashes(current) != desired[:expected_count]:
            raise ValueError(f"Upload read-back mismatch: {key}")
        save()
    checkpoint["groups"][key] = "verified"
    save()


def upload_image(api, edit_id, key, row):
    from googleapiclient.http import MediaFileUpload

    if hashlib.sha256(Path(row["file"]).read_bytes()).hexdigest() != row["sha256"]:
        raise ValueError(f"Source changed after preflight: {row['file']}")
    locale, kind = key.split("/")
    result = (
        api.edits()
        .images()
        .upload(
            packageName=PACKAGE,
            editId=edit_id,
            language=locale,
            imageType=kind,
            media_body=MediaFileUpload(row["file"], mimetype=row["mimetype"], resumable=False),
        )
        .execute()
    )
    if result["image"]["sha256"].lower() != row["sha256"]:
        raise ValueError(f"Uploaded image checksum mismatch: {key}")


def stage(api, edit_id, baseline, groups, videos, checkpoint, save):
    if baseline["edit"]["id"] != edit_id:
        raise ValueError("Staging requires the same edit as the before snapshot")
    current = snapshot(api, edit_id)
    assert_preserved(current, baseline, groups, videos)
    # google_play_assets.py preflights all untouched groups before deleting any.
    for key, rows in groups.items():
        if key not in checkpoint["groups"]:
            images = current["images"][key]
            if identities(images) != identities(baseline["images"][key]) and hashes(images) != [
                row["sha256"] for row in rows
            ]:
                raise ValueError(f"Image group changed since baseline: {key}")
    for key, rows in groups.items():
        stage_group(api, edit_id, key, rows, baseline["images"][key], checkpoint, save, upload_image)
    previous = indexed(baseline["listings"], "language")
    for locale, row in videos.items():
        resource = api.edits().listings()
        current = resource.get(packageName=PACKAGE, editId=edit_id, language=locale).execute()
        desired = {**previous[locale], "video": row["url"]}
        if current not in [previous[locale], desired]:
            raise ValueError(f"Listing changed before video update: {locale}")
        if current != desired:
            resource.update(packageName=PACKAGE, editId=edit_id, language=locale, body=desired).execute()
        actual = resource.get(packageName=PACKAGE, editId=edit_id, language=locale).execute()
        if actual != desired:
            raise ValueError(f"Video read-back mismatch: {locale}")
        checkpoint["videos"][locale] = "verified"
        save()
    checkpoint["result"] = verify(api, edit_id, baseline, groups, videos)
    checkpoint["status"] = "verified_in_edit"
    save()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("snapshot")
    command.add_argument("edit_id")
    command.add_argument("--output", required=True)
    for name in ("stage", "verify"):
        command = commands.add_parser(name)
        command.add_argument("edit_id")
        command.add_argument("manifest")
        command.add_argument("--baseline", required=True)
        command.add_argument("--checkpoint" if name == "stage" else "--output", required=True)
    args = parser.parse_args()
    if args.command == "snapshot":
        if Path(args.output).exists():
            raise ValueError("Refusing to overwrite before snapshot")
        result = snapshot(service(), args.edit_id)
        write_json(args.output, result, create=True)
        print(json.dumps({"snapshot": args.output, "locales": len(result["listings"])}))
        return
    manifest, groups, videos = load_manifest(args.manifest)
    baseline = read_json(args.baseline)
    if args.command == "verify":
        if Path(args.output).exists():
            raise ValueError("Refusing to overwrite verification")
        result = verify(service(), args.edit_id, baseline, groups, videos)
        write_json(args.output, result, create=True)
        print(json.dumps(result))
        return
    identity = {
        "editId": args.edit_id,
        "manifestDigest": digest(manifest),
        "baselineDigest": digest(baseline),
    }
    if Path(args.checkpoint).exists():
        checkpoint = read_json(args.checkpoint)
        if any(checkpoint.get(key) != value for key, value in identity.items()):
            raise ValueError("Checkpoint belongs to a different edit, manifest or baseline")
    else:
        checkpoint = {**identity, "groups": {}, "videos": {}, "status": "started"}
        write_json(args.checkpoint, checkpoint, create=True)
    save = lambda: atomic_json(args.checkpoint, checkpoint)
    stage(service(), args.edit_id, baseline, groups, videos, checkpoint, save)
    print(json.dumps(checkpoint["result"]))


if __name__ == "__main__":
    main()
