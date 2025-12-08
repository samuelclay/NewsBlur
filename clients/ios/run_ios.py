#!/usr/bin/env python3
"""
iOS Simulator Control Script

Usage:
    python3 run_ios.py <action1> <action2> ...

Actions:
    tap:<x>,<y>           - Tap at coordinates
    sleep:<seconds>       - Wait for specified seconds
    swipe:<x1>,<y1>,<x2>,<y2> - Swipe from point to point
    screenshot:<path>     - Take screenshot and save to path
    launch                - Launch the NewsBlur app
    terminate             - Terminate the NewsBlur app
    install               - Install the app from DerivedData

Examples:
    python3 run_ios.py launch sleep:4 tap:100,541 sleep:2 screenshot:/tmp/test.png
    python3 run_ios.py tap:280,836 sleep:2 screenshot:/tmp/askai.png
"""

import subprocess
import sys
import time
import os

# Configuration
UDID = "542DF8D3-CAB2-40BE-8DB2-9CBB864F2881"
BUNDLE_ID = "com.newsblur.NewsBlur"
APP_PATH = "/Users/sclay/Library/Developer/Xcode/DerivedData/NewsBlur-dnwoengkjrcsjaezlhydxgrfmbhw/Build/Products/Debug-iphonesimulator/NewsBlur.app"

# Add idb to PATH
os.environ["PATH"] = os.environ["PATH"] + ":" + os.path.expanduser("~/Library/Python/3.13/bin")


def run_cmd(cmd, description=None):
    """Run a shell command and return output."""
    if description:
        print(f"  -> {description}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0 and result.stderr:
        print(f"  Warning: {result.stderr.strip()}")
    return result.stdout.strip()


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
    if len(parts) != 4:
        print(f"  Error: swipe requires 4 coordinates (x1,y1,x2,y2)")
        return
    x1, y1, x2, y2 = parts
    print(f"  Swipe: ({x1},{y1}) -> ({x2},{y2})")
    run_cmd(f"idb ui swipe --udid {UDID} {x1} {y1} {x2} {y2}")


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
    run_cmd(f"xcrun simctl install {UDID} {APP_PATH}")


def parse_and_execute(action):
    """Parse and execute a single action."""
    if ":" in action:
        cmd, arg = action.split(":", 1)
    else:
        cmd = action
        arg = None

    if cmd == "tap":
        do_tap(arg)
    elif cmd == "sleep":
        do_sleep(arg)
    elif cmd == "swipe":
        do_swipe(arg)
    elif cmd == "screenshot":
        do_screenshot(arg)
    elif cmd == "launch":
        do_launch()
    elif cmd == "terminate":
        do_terminate()
    elif cmd == "install":
        do_install()
    else:
        print(f"  Unknown action: {cmd}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    print("=" * 60)
    print("iOS Simulator Control")
    print("=" * 60)

    for action in sys.argv[1:]:
        parse_and_execute(action)

    print("=" * 60)
    print("Done!")
    print("=" * 60)


if __name__ == "__main__":
    main()
