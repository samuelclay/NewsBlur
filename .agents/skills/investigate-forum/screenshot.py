#!/usr/bin/env python3
"""
screenshot.py: Headless before/after screenshots of a NewsBlur dev stack.

Used by the investigate-forum skill (.agents/skills/investigate-forum/SKILL.md).

Runs Playwright inside the official Playwright docker image. The container shares
the network namespace of the target stack's haproxy container, so inside it
https://localhost is that stack and the localhost session cookie (see
SESSION_COOKIE_DOMAIN in newsblur_web/docker_local_settings.py) works. Nothing
needs to be installed on the host or in the NewsBlur images.

The page logs in through /reader/dev/autologin/<user>/ (DEBUG only), waits for
NEWSBLUR.reader to exist, optionally runs JavaScript, then saves a PNG.

Host usage (run from anywhere):
    python3 .agents/skills/investigate-forum/screenshot.py \
        --workspace forum-13833-wired-newsletters-spam \
        --out .worktree/forum-13833-wired-newsletters-spam/screenshots/before.png

    # Main repo stack, dark theme, run JS first, capture one element
    python3 .agents/skills/investigate-forum/screenshot.py --workspace main --user chrome \
        --js "NEWSBLUR.reader.open_river_stories()" --wait 4000 --theme dark \
        --selector ".NB-story-titles" --out /tmp/after.png

    # Any other container / URL (e.g. the web container directly, no haproxy running)
    python3 .agents/skills/investigate-forum/screenshot.py --container newsblur_web \
        --base-url http://localhost:8000 --out /tmp/shot.png

Requires: docker, and the stack for --workspace already running (make worktree).
The first run builds a small derived image (newsblur-forum-playwright:<version>).
"""

import argparse
import os
import pathlib
import subprocess
import sys

PLAYWRIGHT_VERSION = "1.62.0"
BASE_IMAGE = f"mcr.microsoft.com/playwright/python:v{PLAYWRIGHT_VERSION}-jammy"
# The upstream image ships the browsers but not the Python package, so a tiny derived image
# is built once on this machine (see ensure_image) and reused by every later capture.
PLAYWRIGHT_IMAGE = f"newsblur-forum-playwright:{PLAYWRIGHT_VERSION}"
SKILL_DIR = pathlib.Path(__file__).resolve().parent


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--workspace", help="Worktree name (basename of .worktree/<name>) or 'main' for the main repo")
    parser.add_argument("--container", help="Share this container's network instead of the workspace haproxy")
    parser.add_argument("--base-url", default="https://localhost", help="URL of the stack inside that network")
    parser.add_argument("--user", default="samuel", help="Dev username to autologin as (default samuel)")
    parser.add_argument("--path", default="/", help="Path to open after login (default /)")
    parser.add_argument("--js", action="append", default=[], help="JavaScript to run after load, repeatable, in order")
    parser.add_argument("--wait", type=int, default=2500, help="Milliseconds to wait after load and after each --js")
    parser.add_argument("--selector", help="Screenshot only this CSS selector (first match)")
    parser.add_argument("--theme", choices=["light", "dark", "auto"], help="Switch NewsBlur theme before capture")
    parser.add_argument("--width", type=int, default=1440)
    parser.add_argument("--height", type=int, default=900)
    parser.add_argument("--full-page", action="store_true")
    parser.add_argument("--out", required=True, help="PNG path to write (host path in host mode)")
    parser.add_argument("--image", default=PLAYWRIGHT_IMAGE, help="Docker image to run (built on demand)")
    parser.add_argument("--inner", action="store_true", help=argparse.SUPPRESS)
    return parser


def resolve_container(args):
    if args.container:
        return args.container
    if not args.workspace:
        sys.exit("Pass --workspace <worktree-name>, --workspace main, or --container <name>")
    if args.workspace == "main":
        return "newsblur_haproxy"
    return f"newsblur_haproxy_{args.workspace}"


def container_is_running(name):
    result = subprocess.run(
        ["docker", "inspect", "-f", "{{.State.Running}}", name], capture_output=True, text=True
    )
    return result.returncode == 0 and result.stdout.strip() == "true"


def ensure_image(image):
    """Build the derived Playwright image the first time it is needed."""
    exists = subprocess.run(["docker", "image", "inspect", image], capture_output=True)
    if exists.returncode == 0:
        return
    if image != PLAYWRIGHT_IMAGE:
        sys.exit(f"Image {image} not found locally and it is not the default, so it will not be built here.")
    print(f"Building {image} from {BASE_IMAGE} (one time, pulls ~2GB on first use)", file=sys.stderr)
    dockerfile = f"FROM {BASE_IMAGE}\nRUN pip install --no-cache-dir playwright=={PLAYWRIGHT_VERSION}\n"
    completed = subprocess.run(["docker", "build", "-t", image, "-"], input=dockerfile.encode())
    if completed.returncode != 0:
        sys.exit("docker build failed; see output above")


def run_on_host(args):
    """Launch the Playwright container and re-invoke this file inside it with --inner."""
    container = resolve_container(args)
    ensure_image(args.image)
    if not container_is_running(container):
        sys.exit(
            f"Container {container} is not running. Start the stack first "
            f"(cd .worktree/<name> && make worktree, or make in the main repo)."
        )
    out_path = pathlib.Path(args.out).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    inner_args = [
        "--inner",
        "--base-url", args.base_url,
        "--user", args.user,
        "--path", args.path,
        "--wait", str(args.wait),
        "--width", str(args.width),
        "--height", str(args.height),
        "--out", f"/out/{out_path.name}",
    ]
    for snippet in args.js:
        inner_args += ["--js", snippet]
    if args.selector:
        inner_args += ["--selector", args.selector]
    if args.theme:
        inner_args += ["--theme", args.theme]
    if args.full_page:
        inner_args.append("--full-page")

    command = [
        "docker", "run", "--rm",
        "--network", f"container:{container}",
        "-v", f"{SKILL_DIR}:/skill:ro",
        "-v", f"{out_path.parent}:/out",
        args.image,
        "python", "/skill/screenshot.py", *inner_args,
    ]
    print("Capturing", out_path, "via", container, file=sys.stderr)
    completed = subprocess.run(command)
    if completed.returncode != 0:
        sys.exit(completed.returncode)
    print(out_path)


def run_inner(args):
    """Runs inside the Playwright image."""
    from urllib.parse import quote

    from playwright.sync_api import sync_playwright

    login_url = f"{args.base_url}/reader/dev/autologin/{args.user}/?next={quote(args.path, safe='/?=&')}"
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        context = browser.new_context(
            viewport={"width": args.width, "height": args.height},
            ignore_https_errors=True,
            device_scale_factor=2,
        )
        page = context.new_page()
        page.goto(login_url, wait_until="load", timeout=90000)
        # Reader pages boot Backbone asynchronously; wait for the app object before poking at it.
        try:
            page.wait_for_function("window.NEWSBLUR && window.NEWSBLUR.reader", timeout=30000)
        except Exception:
            print("NEWSBLUR.reader never appeared; capturing the page as-is", file=sys.stderr)
        page.wait_for_timeout(args.wait)
        if args.theme:
            page.evaluate(f"NEWSBLUR.reader.switch_theme({args.theme!r})")
            page.wait_for_timeout(500)
        for snippet in args.js:
            page.evaluate(snippet)
            page.wait_for_timeout(args.wait)
        if args.selector:
            page.wait_for_selector(args.selector, timeout=30000)
            page.locator(args.selector).first.screenshot(path=args.out)
        else:
            page.screenshot(path=args.out, full_page=args.full_page)
        browser.close()


def main():
    args = build_parser().parse_args()
    if args.inner:
        run_inner(args)
    else:
        run_on_host(args)


if __name__ == "__main__":
    main()
