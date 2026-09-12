#!/usr/bin/env python3
"""
iOS Simulator Control Script

Usage:
    python3 run_ios.py list
    python3 run_ios.py --udid <UDID> <action1> <action2> ...

Options:
    --udid <UDID>         - Simulator UDID to target (required for all actions except list)

Actions:
    list                  - List available simulators with UDIDs
    tap:<x>,<y>           - Tap at coordinates
    text:<text>          - Type into the focused field
    key:<code>           - Send a hardware key code (40 is Return)
    sleep:<seconds>       - Wait for specified seconds
    swipe:<x1>,<y1>,<x2>,<y2> - Swipe from point to point
    swipe:<x1>,<y1>,<x2>,<y2>,<seconds> - Swipe with an explicit duration
    capture:<directory>   - Record video, CPU samples, and optional app measurements
    coldcapture:<directory> - Record an app restart, preserving its data and login
    checkpoint:<name>     - Timestamp a navigation/load event in the current capture
    fuzz:<seed>,<count>    - Repeat deterministic vertical scrolling gestures (portrait iPhone)
    describe              - Print simulator accessibility elements
    crashes               - Show recent app exception messages from the simulator
    logs                  - Show recent NewsBlur logs from the simulator
    push:<payload.apns>    - Deliver a local notification payload to the selected app
    screenshot:<path>     - Take screenshot and save to path
    launch                - Launch the NewsBlur app
    terminate             - Terminate the NewsBlur app
    install               - Install the app from DerivedData

Examples:
    python3 run_ios.py list
    python3 run_ios.py --udid 08D78CD0-FA2A-49BF-BF2E-E81EA576CD40 launch sleep:4 screenshot:/tmp/test.png

Environment:
    IOS_SIM_UDID     - Simulator UDID (alternative to --udid flag)
    IOS_BUNDLE_ID    - App bundle identifier (defaults to NewsBlur)
    IOS_APP_PATH     - Path to the built .app for install
    IOS_USE_XCTRACE  - Also record an Instruments trace when set to 1
    IOS_SAMPLE_SECONDS - Maximum CPU profile duration (defaults to 600)
"""

import os
import json
import random
import re
import shlex
import shutil
import site
import signal
import subprocess
import sys
import time

# Configuration
UDID = os.environ.get("IOS_SIM_UDID", "")
BUNDLE_ID = os.environ.get("IOS_BUNDLE_ID", "com.newsblur.NewsBlur")
APP_PATH = os.environ.get(
    "IOS_APP_PATH",
    "/Users/sclay/Library/Developer/Xcode/DerivedData/NewsBlur-dnwoengkjrcsjaezlhydxgrfmbhw/Build/Products/Debug-iphonesimulator/NewsBlur.app",
)

# run_ios.py keeps measurement tools alive across a sequence of UI actions.
CAPTURES = []
CAPTURE_DIRECTORIES = []


def prepend_to_path(path):
    """Prepend a directory to PATH if it exists and is not already present."""
    if not path or not os.path.isdir(path):
        return

    path_entries = os.environ.get("PATH", "").split(":")
    if path in path_entries:
        return

    os.environ["PATH"] = path + ":" + os.environ.get("PATH", "")


# Make sure the idb client and idb_companion are discoverable regardless of
# the Python minor version that installed them. Prefer ~/bin last so a local
# wrapper can override broken version-specific entrypoints created by pip.
prepend_to_path("/usr/local/bin")
prepend_to_path("/opt/homebrew/bin")
prepend_to_path(os.path.join(site.getuserbase(), "bin"))
prepend_to_path(os.path.expanduser("~/bin"))


def run_cmd(cmd, description=None):
    """Run a shell command and return output."""
    if description:
        print(f"  -> {description}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0 and result.stderr:
        print(f"  Warning: {result.stderr.strip()}")
    return result.stdout.strip()


def do_list():
    """List available simulators with UDIDs."""
    output = run_cmd("xcrun simctl list devices available")
    print("Available iOS Simulators:")
    print("-" * 70)
    current_runtime = ""
    for line in output.splitlines():
        line = line.strip()
        if line.startswith("--"):
            current_runtime = line.strip("- ")
        else:
            match = re.match(r"(.+?)\s+\(([A-F0-9-]+)\)\s+\((\w+)\)", line)
            if match:
                name, udid, state = match.groups()
                marker = " <-- BOOTED" if state == "Booted" else ""
                print(f"  {state:<10} {name:<30} {udid}{marker}")
    print("-" * 70)
    print()
    print("Usage: python3 run_ios.py --udid <UDID> <actions...>")
    print("   or: IOS_SIM_UDID=<UDID> python3 run_ios.py <actions...>")


def do_tap(coords):
    """Tap at x,y coordinates."""
    x, y = coords.split(",")
    print(f"  Tap: ({x}, {y})")
    run_cmd(f"idb ui tap --udid {UDID} {x} {y}")


def do_sleep(seconds):
    """Sleep for specified seconds."""
    secs = float(seconds)
    print(f"  Sleep: {secs}s")
    time.sleep(secs)


def do_swipe(coords):
    """Swipe from x1,y1 to x2,y2."""
    parts = coords.split(",")
    if len(parts) not in (4, 5):
        raise ValueError("swipe requires x1,y1,x2,y2[,duration]")
    x1, y1, x2, y2 = parts[:4]
    duration = float(parts[4]) if len(parts) == 5 else 0.3
    print(f"  Swipe: ({x1},{y1}) -> ({x2},{y2})")
    subprocess.run(["idb", "ui", "swipe", "--udid", UDID, x1, y1, x2, y2,
                    "--duration", str(duration)], check=True)


def do_capture(path, cold=False):
    """Record video and CPU samples until run_ios.py finishes its actions."""
    os.makedirs(path, exist_ok=True)
    if cold:
        do_terminate()
    video_log = open(os.path.join(path, "video.log"), "w")
    video = subprocess.Popen(
        ["xcrun", "simctl", "io", UDID, "recordVideo", "--codec=h264", os.path.join(path, "scroll.mp4")],
        stdout=video_log, stderr=subprocess.STDOUT
    )
    CAPTURES.append((video, video_log))
    time.sleep(1)
    launch_requested_at = time.time()
    launch_output = subprocess.check_output(
        ["xcrun", "simctl", "launch", UDID, BUNDLE_ID], text=True
    )
    pid = str(int(launch_output.rsplit(":", 1)[1].strip()))
    sample_cpu = os.environ.get("IOS_CAPTURE_CPU", "1") != "0"
    commands = [
        ("profile", ["sample", pid, os.environ.get("IOS_SAMPLE_SECONDS", "600"), "1",
                     "-file", os.path.join(path, "cpu.txt")]),
    ] if sample_cpu else []
    if os.environ.get("IOS_USE_XCTRACE") == "1":
        commands.append(("instruments", ["xcrun", "xctrace", "record", "--template", "Time Profiler",
                                        "--device", UDID, "--attach", pid, "--no-prompt",
                                        "--output", os.path.join(path, "cpu.trace")]))
    for name, command in commands:
        log = open(os.path.join(path, name + ".log"), "w")
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        CAPTURES.append((process, log))
    time.sleep(4)
    for process, _ in CAPTURES:
        if process.poll() is not None:
            raise RuntimeError("Capture failed to start; inspect capture logs")
    metadata = {"udid": UDID, "bundle_id": BUNDLE_ID, "pid": pid,
                "started_at": launch_requested_at if cold else time.time(),
                "cold_launch": cold, "launch_requested_at": launch_requested_at,
                "cpu_sampling": sample_cpu}
    with open(os.path.join(path, "session.json"), "w") as file:
        json.dump(metadata, file, indent=2)
    CAPTURE_DIRECTORIES.append(path)


def do_fuzz(arguments):
    """Replay bounded vertical gestures; never tap read-state controls."""
    seed, count = map(int, arguments.split(","))
    rng = random.Random(seed)
    for index in range(count):
        # run_ios.py uses safe content coordinates on the portrait iPhone 17e.
        x = rng.randint(135, 260)
        low, high = rng.randint(600, 720), rng.randint(220, 300)
        start, end = (high, low) if index % 4 == 3 else (low, high)
        duration = rng.choice([0.12, 0.18, 0.3, 0.6])
        print(json.dumps({"seed": seed, "gesture": index, "x": x,
                          "start_y": start, "end_y": end, "duration": duration}), flush=True)
        do_swipe(f"{x},{start},{x},{end},{duration}")
        time.sleep(0.25)


def do_checkpoint(name):
    """Record a named timestamp for matching navigation with app measurements."""
    event = {"checkpoint": name, "at": time.time()}
    for path in CAPTURE_DIRECTORIES:
        with open(os.path.join(path, "checkpoints.jsonl"), "a") as file:
            file.write(json.dumps(event) + "\n")
    print(json.dumps(event), flush=True)


def stop_captures():
    ended_at = time.time()
    for process, _ in CAPTURES:
        if process.poll() is None:
            process.send_signal(signal.SIGINT)
    for process, log in CAPTURES:
        try:
            process.wait(timeout=60)
        except subprocess.TimeoutExpired:
            process.terminate()
            process.wait(timeout=10)
        finally:
            log.close()
    CAPTURES.clear()
    for path in CAPTURE_DIRECTORIES:
        metadata_path = os.path.join(path, "session.json")
        with open(metadata_path) as file:
            metadata = json.load(file)
        metadata["ended_at"] = ended_at
        with open(metadata_path, "w") as file:
            json.dump(metadata, file, indent=2)
        container = subprocess.check_output(
            ["xcrun", "simctl", "get_app_container", UDID, BUNDLE_ID, "data"], text=True
        ).strip()
        measurements = os.path.join(container, "Documents", "scroll-performance.jsonl")
        if os.path.exists(measurements):
            shutil.copy2(measurements, os.path.join(path, "measurements.jsonl"))
    CAPTURE_DIRECTORIES.clear()


def do_screenshot(path):
    """Take screenshot and save to path."""
    print(f"  Screenshot: {path}")
    run_cmd(f"xcrun simctl io {UDID} screenshot {path}")


def do_launch():
    """Launch the NewsBlur app."""
    print("  Launching NewsBlur...")
    result = run_cmd(f"xcrun simctl launch {UDID} {BUNDLE_ID}")
    print(f"  {result}")


def do_terminate():
    """Terminate the NewsBlur app."""
    print("  Terminating NewsBlur...")
    run_cmd(f"xcrun simctl terminate {UDID} {BUNDLE_ID} 2>/dev/null")


def do_install():
    """Install the app from DerivedData."""
    print("  Installing NewsBlur...")
    if not os.path.exists(APP_PATH):
        print(f"  Error: APP_PATH does not exist: {APP_PATH}")
        return
    quoted_path = shlex.quote(APP_PATH)
    run_cmd(f"xcrun simctl install {UDID} {quoted_path}")


def parse_and_execute(action):
    """Parse and execute a single action."""
    if ":" in action:
        cmd, arg = action.split(":", 1)
    else:
        cmd = action
        arg = None

    if cmd == "tap":
        do_tap(arg)
    elif cmd == "text":
        subprocess.run(["idb", "ui", "text", "--udid", UDID, arg], check=True)
    elif cmd == "key":
        subprocess.run(["idb", "ui", "key", "--udid", UDID, str(int(arg))], check=True)
    elif cmd == "sleep":
        do_sleep(arg)
    elif cmd == "swipe":
        do_swipe(arg)
    elif cmd == "capture":
        do_capture(arg)
    elif cmd == "coldcapture":
        do_capture(arg, cold=True)
    elif cmd == "checkpoint":
        do_checkpoint(arg)
    elif cmd == "fuzz":
        do_fuzz(arg)
    elif cmd == "describe":
        subprocess.run(["idb", "ui", "describe-all", "--udid", UDID, "--json"], check=True)
    elif cmd == "push":
        subprocess.run(["xcrun", "simctl", "push", UDID, BUNDLE_ID, arg], check=True)
    elif cmd == "logs":
        subprocess.run(["xcrun", "simctl", "spawn", UDID, "log", "show", "--last", "10m",
                        "--style", "compact", "--predicate", 'process == "NB Alpha" OR process == "NewsBlur"'], check=True)
    elif cmd == "crashes":
        predicate = '(process == "NB Alpha" OR process == "NewsBlur") AND (eventMessage CONTAINS "unrecognized selector" OR eventMessage CONTAINS "uncaught exception")'
        subprocess.run(["xcrun", "simctl", "spawn", UDID, "log", "show", "--last", "10m",
                        "--style", "compact", "--predicate", predicate], check=True)
    elif cmd == "screenshot":
        do_screenshot(arg)
    elif cmd == "launch":
        do_launch()
    elif cmd == "terminate":
        do_terminate()
    elif cmd == "install":
        do_install()
    elif cmd == "list":
        do_list()
    else:
        print(f"  Unknown action: {cmd}")


def main():
    global UDID

    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    # Parse --udid flag
    args = sys.argv[1:]
    actions = []
    i = 0
    while i < len(args):
        if args[i] == "--udid" and i + 1 < len(args):
            UDID = args[i + 1]
            i += 2
        else:
            actions.append(args[i])
            i += 1

    if not actions:
        print(__doc__)
        sys.exit(1)

    # "list" doesn't require a UDID
    if actions == ["list"]:
        do_list()
        return

    # All other actions require a UDID
    if not UDID:
        print("Error: No simulator UDID specified.\n")
        do_list()
        sys.exit(1)

    print("=" * 60)
    print(f"iOS Simulator Control (UDID: {UDID})")
    print("=" * 60)

    try:
        for action in actions:
            parse_and_execute(action)
    finally:
        stop_captures()

    print("=" * 60)
    print("Done!")
    print("=" * 60)


if __name__ == "__main__":
    main()
