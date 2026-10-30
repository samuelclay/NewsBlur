#!/usr/bin/env python3
"""
run.py: End-to-end tests and screenshots of the web reader's phone layout.

Used by the mobile-web skill (.agents/skills/mobile-web/SKILL.md).

Runs a scenario from scenarios/ in the official Playwright docker image, inside the network
namespace of a running NewsBlur stack's haproxy container, so https://localhost inside the
container is that stack. Scenarios log in through /reader/dev/autologin/<user>/ (DEBUG only),
emulate a phone with real CDP touch events, and print PASS/FAIL lines. Any FAIL, or an
exception, makes the run exit non-zero.

Scenarios change the dev account's settings as they go (layout toggles, Feed/Text choices,
theme). Every run snapshots the account's view_settings and preferences in the web container
first and puts back whatever changed afterwards, even when the scenario fails.

Host usage (from the repo root or a worktree):
    python3 .agents/skills/mobile-web/run.py smoke
    python3 .agents/skills/mobile-web/run.py tour --args dark --out /tmp/phone-dark
    python3 .agents/skills/mobile-web/run.py smoke modals rtl --workspace mobile-web
    python3 .agents/skills/mobile-web/run.py all --feed 476

Requires: docker, and the stack already running (make, or make worktree in a worktree).
The first run builds the same small derived Playwright image the investigate-forum
screenshot helper uses (newsblur-forum-playwright:<version>).
"""

import argparse
import os
import pathlib
import subprocess
import sys

PLAYWRIGHT_VERSION = "1.62.0"
BASE_IMAGE = f"mcr.microsoft.com/playwright/python:v{PLAYWRIGHT_VERSION}-jammy"
PLAYWRIGHT_IMAGE = f"newsblur-forum-playwright:{PLAYWRIGHT_VERSION}"
SKILL_DIR = pathlib.Path(__file__).resolve().parent
SCENARIO_DIR = SKILL_DIR / "scenarios"
GUARD_PATH_IN_CONTAINER = "/tmp/mobile_web_prefs_guard.py"
SNAPSHOT_PATH_IN_CONTAINER = "/tmp/mobile_web_prefs_snapshot.json"
# run.py: "all" skips next_unread, which marks a feed's unread stories read as it goes.
DEFAULT_ALL = ["smoke", "modals", "player", "rtl", "landscape", "tablet", "resize", "desktop", "safari"]


def available_scenarios():
    return sorted(path.stem for path in SCENARIO_DIR.glob("*.py") if not path.stem.startswith("_"))


def build_parser():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "scenarios",
        nargs="+",
        help="Scenario names from scenarios/ (%s), or 'all'" % ", ".join(available_scenarios()),
    )
    parser.add_argument(
        "--workspace",
        help="Worktree name (basename of .worktree/<name>) or 'main'. Defaults to the current checkout.",
    )
    parser.add_argument("--user", default="samuel", help="Dev username to autologin as (default samuel)")
    parser.add_argument(
        "--feed", type=int, help="Feed id to test with (default: the visible feed with most stories)"
    )
    parser.add_argument(
        "--args", default="", help="Extra argument passed to each scenario (tour takes light or dark)"
    )
    parser.add_argument("--out", default="/tmp/newsblur-mobile-web", help="Directory for screenshots")
    parser.add_argument("--image", default=PLAYWRIGHT_IMAGE, help="Docker image to run (built on demand)")
    return parser


def default_workspace():
    """The checkout this script was run from: a worktree's directory name, or main."""
    cwd = pathlib.Path.cwd().resolve()
    for path in [cwd, *cwd.parents]:
        if path.parent.name == ".worktree":
            return path.name
        if (path / ".git").is_dir():
            return "main"
    return "main"


def container_names(workspace):
    if workspace == "main":
        return "newsblur_haproxy", "newsblur_web"
    return f"newsblur_haproxy_{workspace}", f"newsblur_web_{workspace}"


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


def run_guard(web_container, mode, user):
    """Snapshots or restores the dev account's settings with prefs_guard.py in the web container."""
    code = (
        "import importlib.util as u; "
        f"s = u.spec_from_file_location('g', '{GUARD_PATH_IN_CONTAINER}'); "
        "g = u.module_from_spec(s); s.loader.exec_module(g); "
        f"g.main('{mode}', '{SNAPSHOT_PATH_IN_CONTAINER}', '{user}')"
    )
    result = subprocess.run(
        ["docker", "exec", web_container, "python", "manage.py", "shell", "-c", code],
        capture_output=True,
        text=True,
    )
    lines = [line for line in result.stdout.splitlines() if line.startswith("prefs_guard:")]
    if result.returncode != 0 or not lines:
        sys.exit(f"prefs_guard {mode} failed in {web_container}:\n{result.stderr[-2000:]}")
    print(lines[-1], file=sys.stderr)


def run_scenario(name, args, haproxy_container, out_dir):
    command = [
        "docker",
        "run",
        "--rm",
        "--network",
        f"container:{haproxy_container}",
        "-v",
        f"{SKILL_DIR}:/skill:ro",
        "-v",
        f"{out_dir}:/out",
        args.image,
        "python",
        "/skill/harness.py",
        "--scenario",
        name,
        "--user",
        args.user,
        "--out",
        "/out",
        "--args",
        args.args,
    ]
    if args.feed:
        command += ["--feed", str(args.feed)]
    print(f"== {name} ==", file=sys.stderr)
    return subprocess.run(command).returncode


def main():
    args = build_parser().parse_args()
    names = available_scenarios()
    scenarios = DEFAULT_ALL if args.scenarios == ["all"] else args.scenarios
    unknown = [name for name in scenarios if name not in names]
    if unknown:
        sys.exit(f"Unknown scenario(s): {', '.join(unknown)}. Available: {', '.join(names)}")

    workspace = args.workspace or default_workspace()
    haproxy_container, web_container = container_names(workspace)
    for container in (haproxy_container, web_container):
        if not container_is_running(container):
            sys.exit(
                f"Container {container} is not running. Start the stack first "
                f"(cd .worktree/<name> && make worktree, or make in the main repo)."
            )
    ensure_image(args.image)
    out_dir = pathlib.Path(args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    subprocess.run(
        ["docker", "cp", str(SKILL_DIR / "prefs_guard.py"), f"{web_container}:{GUARD_PATH_IN_CONTAINER}"],
        check=True,
        capture_output=True,
    )
    failed = []
    run_guard(web_container, "save", args.user)
    try:
        for name in scenarios:
            if run_scenario(name, args, haproxy_container, out_dir) != 0:
                failed.append(name)
    finally:
        run_guard(web_container, "restore", args.user)

    print(f"Screenshots in {out_dir}", file=sys.stderr)
    if failed:
        print(f"FAILED: {', '.join(failed)}", file=sys.stderr)
        sys.exit(1)
    print(f"All passed: {', '.join(scenarios)}", file=sys.stderr)


if __name__ == "__main__":
    os.environ.setdefault("PYTHONUNBUFFERED", "1")
    main()
