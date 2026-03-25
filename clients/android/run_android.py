#!/usr/bin/env python3
"""
Android Emulator Control Script

Usage:
    python3 run_android.py list
    python3 run_android.py --avd <AVD_NAME> start
    python3 run_android.py --serial <SERIAL> <action1> <action2> ...

Options:
    --serial <SERIAL>         Emulator or device serial to target
    --avd <AVD_NAME>          AVD name to target when listing or starting
    --variant <VARIANT>       Build variant to use (default: debug)
    --apk-path <PATH>         Explicit APK path for install
    --appium-port <PORT>      Appium server port (default: 4723)
    --verbose                 Print commands before executing

Actions:
    list                          List available AVDs and connected devices
    start                         Start the requested AVD and wait for boot completion
    build                         Build the configured APK variant
    install                       Install the APK on the target device
    launch                        Launch the NewsBlur app
    terminate                     Force-stop the NewsBlur app
    screenshot:<path>             Save a screenshot to path
    source[:path]                 Dump the Appium XML hierarchy to stdout or a file
    tap:<x>,<y>                   Tap coordinates via adb
    swipe:<x1>,<y1>,<x2>,<y2>[,<ms>]  Swipe via adb (default duration: 300ms)
    sleep:<seconds>               Sleep for the specified number of seconds
    tap_xpath:<xpath>             Tap the first element matching an XPath
    tap_id:<resource_id>          Tap the first element matching a resource-id
    tap_text:<text>               Tap the first element whose text or content-desc matches
    tap_accessibility_id:<text>   Tap the first element matching an accessibility id
    wait_xpath:<xpath>[,<secs>]   Wait for an XPath to appear (default: 15s)

Examples:
    python3 run_android.py list
    python3 run_android.py --avd NewsBlur_API_36 start build install launch
    python3 run_android.py --serial emulator-5554 source:/tmp/newsblur.xml
    python3 run_android.py --serial emulator-5554 tap_text:"Log in"
    python3 run_android.py --serial emulator-5554 tap_xpath:"//*[@resource-id='com.newsblur:id/login_button']"

Environment:
    ANDROID_HOME / ANDROID_SDK_ROOT
    ANDROID_SERIAL
    ANDROID_AVD
    ANDROID_BUILD_VARIANT
    ANDROID_PROJECT_DIR
    ANDROID_APK_PATH
    ANDROID_APP_PACKAGE          (default: com.newsblur)
    ANDROID_APP_ACTIVITY         (default: com.newsblur.activity.InitActivity)
    ANDROID_APPIUM_PORT          (default: 4723)
    ANDROID_EMULATOR_ARGS
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_PROJECT_DIR = SCRIPT_DIR / "NewsBlur"
DEFAULT_ANDROID_HOME_CANDIDATES = (
    os.environ.get("ANDROID_HOME"),
    os.environ.get("ANDROID_SDK_ROOT"),
    str(Path.home() / "Library" / "Android" / "sdk"),
    str(Path.home() / "Android" / "Sdk"),
)
W3C_ELEMENT_KEY = "element-6066-11e4-a52e-4f735466cecf"


class RunnerError(RuntimeError):
    pass


@dataclass
class RuntimeConfig:
    android_home: Path
    adb_path: Path
    emulator_path: Path
    appium_path: str
    project_dir: Path
    app_package: str
    app_activity: str
    variant: str
    apk_path: Path | None
    serial: str | None
    avd: str | None
    appium_port: int
    verbose: bool
    emulator_args: str
    session: "AppiumSession | None" = None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Control the NewsBlur Android emulator.")
    parser.add_argument("--serial", default=os.environ.get("ANDROID_SERIAL"))
    parser.add_argument("--avd", default=os.environ.get("ANDROID_AVD"))
    parser.add_argument("--variant", default=os.environ.get("ANDROID_BUILD_VARIANT", "debug"))
    parser.add_argument("--apk-path", default=os.environ.get("ANDROID_APK_PATH"))
    parser.add_argument(
        "--project-dir", default=os.environ.get("ANDROID_PROJECT_DIR", str(DEFAULT_PROJECT_DIR))
    )
    parser.add_argument("--appium-port", type=int, default=int(os.environ.get("ANDROID_APPIUM_PORT", "4723")))
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("actions", nargs="*")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not args.actions:
        print(__doc__)
        sys.exit(1)

    runtime = build_runtime(args)
    if args.actions == ["list"]:
        do_list(runtime)
        return

    print("=" * 60)
    print("Android Emulator Control")
    print("=" * 60)

    try:
        for action in args.actions:
            parse_and_execute(runtime, action)
    finally:
        if runtime.session:
            runtime.session.close()

    print("=" * 60)
    print("Done!")
    print("=" * 60)


def build_runtime(args: argparse.Namespace) -> RuntimeConfig:
    android_home = find_android_home()
    adb_path = require_file(android_home / "platform-tools" / "adb", "adb")
    emulator_path = require_file(android_home / "emulator" / "emulator", "Android emulator")
    project_dir = Path(args.project_dir).expanduser().resolve()
    appium_path = shutil.which("appium") or "/opt/homebrew/bin/appium"
    if not shutil.which(appium_path) and not Path(appium_path).exists():
        raise RunnerError("Could not find the Appium executable. Install Appium or update PATH.")

    apk_path = Path(args.apk_path).expanduser().resolve() if args.apk_path else None

    return RuntimeConfig(
        android_home=android_home,
        adb_path=adb_path,
        emulator_path=emulator_path,
        appium_path=appium_path,
        project_dir=project_dir,
        app_package=os.environ.get("ANDROID_APP_PACKAGE", "com.newsblur"),
        app_activity=os.environ.get("ANDROID_APP_ACTIVITY", "com.newsblur.activity.InitActivity"),
        variant=args.variant,
        apk_path=apk_path,
        serial=args.serial,
        avd=args.avd,
        appium_port=args.appium_port,
        verbose=args.verbose,
        emulator_args=os.environ.get("ANDROID_EMULATOR_ARGS", ""),
    )


def find_android_home() -> Path:
    for candidate in DEFAULT_ANDROID_HOME_CANDIDATES:
        if not candidate:
            continue
        path = Path(candidate).expanduser()
        if path.exists():
            return path.resolve()
    raise RunnerError("Could not find ANDROID_HOME. Set ANDROID_HOME or ANDROID_SDK_ROOT.")


def require_file(path: Path, label: str) -> Path:
    if not path.exists():
        raise RunnerError(f"Could not find {label} at {path}")
    return path


def run_cmd(
    runtime: RuntimeConfig,
    cmd: list[str],
    description: str | None = None,
    *,
    cwd: Path | None = None,
    check: bool = True,
    capture_output: bool = True,
    timeout: float | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    if description:
        print(f"  -> {description}")
    if runtime.verbose:
        location = f" (cwd={cwd})" if cwd else ""
        print(f"     {' '.join(shlex.quote(part) for part in cmd)}{location}")
    result = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        capture_output=capture_output,
        text=True,
        check=False,
        timeout=timeout,
        env=env,
    )
    if check and result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or f"Command failed: {' '.join(cmd)}"
        raise RunnerError(message)
    return result


def adb_cmd(
    runtime: RuntimeConfig,
    args: list[str],
    description: str | None = None,
    *,
    serial: str | None = None,
    check: bool = True,
    capture_output: bool = True,
    timeout: float | None = None,
) -> subprocess.CompletedProcess[str]:
    cmd = [str(runtime.adb_path)]
    target_serial = serial or runtime.serial
    if target_serial:
        cmd.extend(["-s", target_serial])
    cmd.extend(args)
    return run_cmd(
        runtime,
        cmd,
        description,
        check=check,
        capture_output=capture_output,
        timeout=timeout,
    )


def do_list(runtime: RuntimeConfig) -> None:
    avds = list_avds(runtime)
    devices = list_devices(runtime)
    print("Available Android AVDs:")
    print("-" * 70)
    if not avds:
        print("  (none)")
    for avd in avds:
        running = next((device for device in devices if device.get("avd_name") == avd), None)
        marker = f" <-- RUNNING on {running['serial']}" if running and running["state"] == "device" else ""
        print(f"  {avd}{marker}")
    print("-" * 70)
    print("Connected Android Devices:")
    print("-" * 70)
    if not devices:
        print("  (none)")
    for device in devices:
        details = f" {device['details']}" if device["details"] else ""
        avd_text = f" [{device['avd_name']}]" if device.get("avd_name") else ""
        print(f"  {device['state']:<10} {device['serial']}{avd_text}{details}")
    print("-" * 70)
    print()
    print("Usage: python3 run_android.py --avd <AVD_NAME> start build install launch")
    print("   or: python3 run_android.py --serial <SERIAL> source:/tmp/newsblur.xml")


def list_avds(runtime: RuntimeConfig) -> list[str]:
    result = run_cmd(runtime, [str(runtime.emulator_path), "-list-avds"], check=True)
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def list_devices(runtime: RuntimeConfig) -> list[dict[str, str]]:
    result = adb_cmd(runtime, ["devices", "-l"], check=True)
    configured_avds = list_avds(runtime)
    devices: list[dict[str, str]] = []
    for line in result.stdout.splitlines()[1:]:
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        serial = parts[0]
        state = parts[1]
        details = " ".join(parts[2:])
        device = {"serial": serial, "state": state, "details": details}
        if serial.startswith("emulator-") and state == "device":
            avd_name = get_avd_name_for_serial(runtime, serial)
            if avd_name:
                device["avd_name"] = avd_name
        devices.append(device)
    ready_emulators = [
        device
        for device in devices
        if device["serial"].startswith("emulator-") and device["state"] == "device"
    ]
    if len(configured_avds) == 1 and len(ready_emulators) == 1 and "avd_name" not in ready_emulators[0]:
        ready_emulators[0]["avd_name"] = configured_avds[0]
    return devices


def get_avd_name_for_serial(runtime: RuntimeConfig, serial: str) -> str | None:
    try:
        result = adb_cmd(
            runtime,
            ["emu", "avd", "name"],
            serial=serial,
            check=False,
            timeout=2,
        )
    except subprocess.TimeoutExpired:
        return None
    if result.returncode != 0:
        return None
    for line in result.stdout.splitlines():
        value = line.strip()
        if value and value != "OK":
            return value
    return None


def default_avd(runtime: RuntimeConfig) -> str | None:
    avds = list_avds(runtime)
    if len(avds) == 1:
        return avds[0]
    return None


def default_apk_path(runtime: RuntimeConfig) -> Path:
    if runtime.apk_path:
        return runtime.apk_path
    variant = runtime.variant.replace("_", "-")
    return runtime.project_dir / "app" / "build" / "outputs" / "apk" / variant / f"app-{variant}.apk"


def variant_task_suffix(variant: str) -> str:
    return "".join(piece.capitalize() for piece in variant.replace("-", "_").split("_") if piece)


def resolve_serial(runtime: RuntimeConfig, *, required: bool = True) -> str | None:
    devices = list_devices(runtime)
    device_by_serial = {device["serial"]: device for device in devices}

    if runtime.serial:
        if runtime.serial in device_by_serial and device_by_serial[runtime.serial]["state"] == "device":
            return runtime.serial
        if required:
            raise RunnerError(f"Device {runtime.serial} is not connected and ready.")
        return None

    if runtime.avd:
        for device in devices:
            if device.get("avd_name") == runtime.avd and device["state"] == "device":
                runtime.serial = device["serial"]
                return runtime.serial
        if required:
            raise RunnerError(f"Could not find a running device for AVD {runtime.avd}.")
        return None

    ready_devices = [device for device in devices if device["state"] == "device"]
    if len(ready_devices) == 1:
        runtime.serial = ready_devices[0]["serial"]
        return runtime.serial

    if required:
        raise RunnerError("Could not resolve a target device. Use --serial or --avd, or run start first.")
    return None


def start_emulator(runtime: RuntimeConfig) -> None:
    avd = runtime.avd or default_avd(runtime)
    if not avd:
        raise RunnerError("No AVD specified. Use --avd or create only one AVD.")
    runtime.avd = avd

    existing_serial = resolve_serial(runtime, required=False)
    if existing_serial:
        print(f"  Emulator already running: {existing_serial} ({avd})")
        wait_for_boot(runtime, existing_serial)
        return

    before = {device["serial"] for device in list_devices(runtime)}
    cmd = [str(runtime.emulator_path), "-avd", avd]
    if runtime.emulator_args:
        cmd.extend(shlex.split(runtime.emulator_args))

    print(f"  Starting emulator for AVD: {avd}")
    if runtime.verbose:
        print(f"     {' '.join(shlex.quote(part) for part in cmd)}")

    stdout = None if runtime.verbose else subprocess.DEVNULL
    stderr = None if runtime.verbose else subprocess.DEVNULL
    process = subprocess.Popen(cmd, stdout=stdout, stderr=stderr, start_new_session=True)

    deadline = time.time() + 180
    while time.time() < deadline:
        if process.poll() is not None and process.returncode not in (0, None):
            raise RunnerError(f"Emulator process exited early with code {process.returncode}.")

        devices = list_devices(runtime)
        matched = next((d for d in devices if d.get("avd_name") == avd and d["state"] == "device"), None)
        if not matched:
            new_serials = [
                d["serial"] for d in devices if d["serial"] not in before and d["state"] == "device"
            ]
            if len(new_serials) == 1:
                matched = next(d for d in devices if d["serial"] == new_serials[0])
        if matched:
            runtime.serial = matched["serial"]
            wait_for_boot(runtime, runtime.serial)
            return
        time.sleep(2)

    raise RunnerError(f"Timed out waiting for emulator {avd} to appear.")


def wait_for_boot(runtime: RuntimeConfig, serial: str) -> None:
    print(f"  Waiting for {serial} to finish booting...")
    adb_cmd(runtime, ["wait-for-device"], serial=serial, check=True, timeout=60)
    deadline = time.time() + 180
    while time.time() < deadline:
        result = adb_cmd(
            runtime,
            ["shell", "getprop", "sys.boot_completed"],
            serial=serial,
            check=False,
            timeout=5,
        )
        if result.stdout.strip() == "1":
            runtime.serial = serial
            adb_cmd(runtime, ["shell", "input", "keyevent", "82"], serial=serial, check=False)
            adb_cmd(runtime, ["shell", "wm", "dismiss-keyguard"], serial=serial, check=False)
            print(f"  Boot complete: {serial}")
            return
        time.sleep(2)
    raise RunnerError(f"Timed out waiting for {serial} to boot.")


def build_app(runtime: RuntimeConfig) -> Path:
    if not runtime.project_dir.exists():
        raise RunnerError(f"Android project directory does not exist: {runtime.project_dir}")
    gradlew = runtime.project_dir / "gradlew"
    if not gradlew.exists():
        raise RunnerError(f"Could not find gradlew at {gradlew}")
    task = f":app:assemble{variant_task_suffix(runtime.variant)}"
    run_cmd(
        runtime, [str(gradlew), task], description=f"Building {runtime.variant} APK", cwd=runtime.project_dir
    )
    apk_path = default_apk_path(runtime)
    if not apk_path.exists():
        raise RunnerError(f"Build completed but APK was not found at {apk_path}")
    print(f"  Built APK: {apk_path}")
    return apk_path


def install_app(runtime: RuntimeConfig) -> None:
    serial = resolve_serial(runtime)
    apk_path = default_apk_path(runtime) if runtime.apk_path else build_app(runtime)
    if runtime.apk_path and not apk_path.exists():
        raise RunnerError(f"APK path does not exist: {apk_path}")
    print(f"  Installing {apk_path.name} on {serial}...")
    adb_cmd(runtime, ["install", "-r", "-t", str(apk_path)], serial=serial, check=True, timeout=180)


def resolve_launch_component(runtime: RuntimeConfig) -> str:
    serial = resolve_serial(runtime)
    result = adb_cmd(
        runtime,
        ["shell", "cmd", "package", "resolve-activity", "--brief", runtime.app_package],
        serial=serial,
        check=False,
        timeout=10,
    )
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if result.returncode == 0 and lines and "/" in lines[-1]:
        return lines[-1]

    activity = runtime.app_activity
    if "/" in activity:
        return activity
    if activity.startswith("."):
        activity = f"{runtime.app_package}{activity}"
    return f"{runtime.app_package}/{activity}"


def launch_app(runtime: RuntimeConfig) -> None:
    serial = resolve_serial(runtime)
    component = resolve_launch_component(runtime)
    print(f"  Launching {component} on {serial}...")
    result = adb_cmd(
        runtime,
        ["shell", "am", "start", "-W", "-n", component],
        serial=serial,
        check=False,
        timeout=30,
    )
    output = result.stdout.strip() or result.stderr.strip()
    if result.returncode == 0 and "Error:" not in output:
        if output:
            print(f"  {output}")
        return

    fallback = adb_cmd(
        runtime,
        ["shell", "monkey", "-p", runtime.app_package, "-c", "android.intent.category.LAUNCHER", "1"],
        serial=serial,
        check=False,
        timeout=30,
    )
    if fallback.returncode != 0:
        raise RunnerError(fallback.stderr.strip() or fallback.stdout.strip() or "Failed to launch app.")


def terminate_app(runtime: RuntimeConfig) -> None:
    serial = resolve_serial(runtime)
    print(f"  Terminating {runtime.app_package} on {serial}...")
    adb_cmd(runtime, ["shell", "am", "force-stop", runtime.app_package], serial=serial, check=False)


def save_screenshot(runtime: RuntimeConfig, path: str) -> None:
    serial = resolve_serial(runtime)
    destination = Path(path).expanduser().resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    print(f"  Screenshot: {destination}")
    with destination.open("wb") as handle:
        cmd = [str(runtime.adb_path), "-s", serial, "exec-out", "screencap", "-p"]
        if runtime.verbose:
            print(f"     {' '.join(shlex.quote(part) for part in cmd)}")
        result = subprocess.run(cmd, stdout=handle, stderr=subprocess.PIPE, check=False)
    if result.returncode != 0:
        raise RunnerError(result.stderr.decode("utf-8", "replace").strip() or "Failed to capture screenshot.")


def do_tap(runtime: RuntimeConfig, coords: str) -> None:
    serial = resolve_serial(runtime)
    x, y = parse_exact_parts(coords, expected=2, label="tap")
    print(f"  Tap: ({x}, {y}) on {serial}")
    adb_cmd(runtime, ["shell", "input", "tap", x, y], serial=serial, check=True)


def do_swipe(runtime: RuntimeConfig, coords: str) -> None:
    serial = resolve_serial(runtime)
    parts = [part.strip() for part in coords.split(",") if part.strip()]
    if len(parts) not in (4, 5):
        raise RunnerError("swipe requires x1,y1,x2,y2[,duration_ms]")
    if len(parts) == 4:
        parts.append("300")
    x1, y1, x2, y2, duration = parts
    print(f"  Swipe: ({x1},{y1}) -> ({x2},{y2}) in {duration}ms on {serial}")
    adb_cmd(runtime, ["shell", "input", "swipe", x1, y1, x2, y2, duration], serial=serial, check=True)


def do_sleep(seconds: str) -> None:
    value = float(seconds)
    print(f"  Sleep: {value}s")
    time.sleep(value)


def dump_source(runtime: RuntimeConfig, path: str | None) -> None:
    session = ensure_session(runtime)
    xml = session.get_source()
    if path:
        destination = Path(path).expanduser().resolve()
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(xml, encoding="utf-8")
        print(f"  Saved XML hierarchy to {destination}")
    else:
        print(xml)


def tap_xpath(runtime: RuntimeConfig, xpath: str) -> None:
    session = ensure_session(runtime)
    print(f"  Tap XPath: {xpath}")
    session.click_first("xpath", xpath)


def tap_id(runtime: RuntimeConfig, resource_id: str) -> None:
    session = ensure_session(runtime)
    qualified_id = qualify_resource_id(runtime, resource_id)
    print(f"  Tap resource-id: {qualified_id}")
    session.click_first("id", qualified_id)


def tap_text(runtime: RuntimeConfig, text: str) -> None:
    session = ensure_session(runtime)
    locator = (
        f"//*[@text={xpath_literal(text)} or @content-desc={xpath_literal(text)}"
        f" or @contentDescription={xpath_literal(text)}]"
    )
    print(f"  Tap text: {text}")
    session.click_first("xpath", locator)


def tap_accessibility_id(runtime: RuntimeConfig, text: str) -> None:
    session = ensure_session(runtime)
    print(f"  Tap accessibility id: {text}")
    session.click_first("accessibility id", text)


def wait_xpath(runtime: RuntimeConfig, value: str) -> None:
    session = ensure_session(runtime)
    xpath, timeout_seconds = split_locator_timeout(value)
    print(f"  Wait XPath ({timeout_seconds}s): {xpath}")
    session.wait_for("xpath", xpath, timeout_seconds)


def ensure_session(runtime: RuntimeConfig) -> "AppiumSession":
    serial = resolve_serial(runtime)
    if not runtime.session:
        runtime.session = AppiumSession(runtime, serial)
    runtime.session.ensure_session()
    return runtime.session


def parse_and_execute(runtime: RuntimeConfig, action: str) -> None:
    if ":" in action:
        cmd, arg = action.split(":", 1)
    else:
        cmd, arg = action, None

    if cmd == "start":
        start_emulator(runtime)
    elif cmd == "build":
        build_app(runtime)
    elif cmd == "install":
        install_app(runtime)
    elif cmd == "launch":
        launch_app(runtime)
    elif cmd == "terminate":
        terminate_app(runtime)
    elif cmd == "tap":
        require_arg(cmd, arg)
        do_tap(runtime, arg)
    elif cmd == "swipe":
        require_arg(cmd, arg)
        do_swipe(runtime, arg)
    elif cmd == "sleep":
        require_arg(cmd, arg)
        do_sleep(arg)
    elif cmd == "screenshot":
        require_arg(cmd, arg)
        save_screenshot(runtime, arg)
    elif cmd == "source":
        dump_source(runtime, arg)
    elif cmd == "tap_xpath":
        require_arg(cmd, arg)
        tap_xpath(runtime, arg)
    elif cmd == "tap_id":
        require_arg(cmd, arg)
        tap_id(runtime, arg)
    elif cmd == "tap_text":
        require_arg(cmd, arg)
        tap_text(runtime, arg)
    elif cmd == "tap_accessibility_id":
        require_arg(cmd, arg)
        tap_accessibility_id(runtime, arg)
    elif cmd == "wait_xpath":
        require_arg(cmd, arg)
        wait_xpath(runtime, arg)
    else:
        raise RunnerError(f"Unknown action: {cmd}")


def require_arg(cmd: str, arg: str | None) -> None:
    if arg is None:
        raise RunnerError(f"{cmd} requires an argument.")


def parse_exact_parts(value: str, *, expected: int, label: str) -> list[str]:
    parts = [part.strip() for part in value.split(",") if part.strip()]
    if len(parts) != expected:
        raise RunnerError(f"{label} requires {expected} comma-separated values.")
    return parts


def split_locator_timeout(value: str) -> tuple[str, float]:
    if "," not in value:
        return value, 15.0
    locator, maybe_timeout = value.rsplit(",", 1)
    try:
        return locator, float(maybe_timeout)
    except ValueError:
        return value, 15.0


def qualify_resource_id(runtime: RuntimeConfig, resource_id: str) -> str:
    if ":" in resource_id:
        return resource_id
    if resource_id.startswith("id/"):
        return f"{runtime.app_package}:{resource_id}"
    if "/" in resource_id:
        return resource_id
    return f"{runtime.app_package}:id/{resource_id}"


def xpath_literal(value: str) -> str:
    if "'" not in value:
        return f"'{value}'"
    if '"' not in value:
        return f'"{value}"'
    pieces = value.split("'")
    quoted = []
    for index, piece in enumerate(pieces):
        if piece:
            quoted.append(f"'{piece}'")
        if index != len(pieces) - 1:
            quoted.append('"\'"')
    return f"concat({', '.join(quoted)})"


class AppiumSession:
    def __init__(self, runtime: RuntimeConfig, serial: str) -> None:
        self.runtime = runtime
        self.serial = serial
        self.base_url = f"http://127.0.0.1:{runtime.appium_port}"
        self.session_id: str | None = None
        self.server_process: subprocess.Popen[bytes] | None = None

    def ensure_session(self) -> None:
        if self.session_id:
            return
        self.ensure_server()
        component = resolve_launch_component(self.runtime)
        activity = component.split("/", 1)[1]
        payload = {
            "capabilities": {
                "alwaysMatch": {
                    "platformName": "Android",
                    "appium:automationName": "UiAutomator2",
                    "appium:deviceName": self.serial,
                    "appium:udid": self.serial,
                    "appium:appPackage": self.runtime.app_package,
                    "appium:appActivity": activity,
                    "appium:autoLaunch": False,
                    "appium:noReset": True,
                    "appium:dontStopAppOnReset": True,
                    "appium:autoGrantPermissions": True,
                    "appium:newCommandTimeout": 600,
                    "appium:adbExecTimeout": 180000,
                    "appium:uiautomator2ServerInstallTimeout": 90000,
                },
                "firstMatch": [{}],
            }
        }
        status, response = self.request("POST", "/session", payload)
        if status not in (200, 201):
            raise RunnerError(self.error_message(response) or "Failed to create Appium session.")

        value = response.get("value", {})
        self.session_id = response.get("sessionId") or value.get("sessionId")
        if not self.session_id:
            raise RunnerError(f"Unexpected Appium session response: {response}")

    def ensure_server(self) -> None:
        if self.server_ready():
            return

        cmd = [
            self.runtime.appium_path,
            "--port",
            str(self.runtime.appium_port),
            "--session-override",
            "--relaxed-security",
            "--log-level",
            "error",
        ]
        print(f"  Starting Appium on port {self.runtime.appium_port}...")
        if self.runtime.verbose:
            print(f"     {' '.join(shlex.quote(part) for part in cmd)}")
        stdout = None if self.runtime.verbose else subprocess.DEVNULL
        stderr = None if self.runtime.verbose else subprocess.DEVNULL
        self.server_process = subprocess.Popen(cmd, stdout=stdout, stderr=stderr, start_new_session=True)

        deadline = time.time() + 30
        while time.time() < deadline:
            if self.server_process.poll() is not None and self.server_process.returncode not in (0, None):
                raise RunnerError(f"Appium exited early with code {self.server_process.returncode}.")
            if self.server_ready():
                return
            time.sleep(1)
        raise RunnerError("Timed out waiting for Appium to start.")

    def server_ready(self) -> bool:
        status, response = self.request("GET", "/status")
        if status != 200:
            return False
        if response.get("status") == 0:
            return True
        value = response.get("value", {})
        return isinstance(value, dict) and value.get("ready") is True

    def get_source(self) -> str:
        self.ensure_session()
        status, response = self.request("GET", f"/session/{self.session_id}/source")
        if status != 200:
            raise RunnerError(self.error_message(response) or "Failed to get page source.")
        return response.get("value", "")

    def click_first(self, using: str, value: str) -> None:
        self.ensure_session()
        element_id = self.find_element(using, value)
        if not element_id:
            raise RunnerError(f"Could not find element using {using}: {value}")
        status, response = self.request("POST", f"/session/{self.session_id}/element/{element_id}/click", {})
        if status != 200:
            raise RunnerError(
                self.error_message(response) or f"Failed to click element using {using}: {value}"
            )

    def wait_for(self, using: str, value: str, timeout_seconds: float) -> None:
        deadline = time.time() + timeout_seconds
        while time.time() < deadline:
            if self.find_element(using, value):
                return
            time.sleep(0.5)
        raise RunnerError(f"Timed out waiting for element using {using}: {value}")

    def find_element(self, using: str, value: str) -> str | None:
        self.ensure_session()
        status, response = self.request(
            "POST",
            f"/session/{self.session_id}/element",
            {"using": using, "value": value},
        )
        if status == 200:
            element = response.get("value", {})
            return element.get(W3C_ELEMENT_KEY) or element.get("ELEMENT")
        if self.error_code(response) == "no such element":
            return None
        raise RunnerError(self.error_message(response) or f"Failed to locate element using {using}: {value}")

    def close(self) -> None:
        if self.session_id:
            self.request("DELETE", f"/session/{self.session_id}")
            self.session_id = None
        if self.server_process and self.server_process.poll() is None:
            self.server_process.terminate()
            try:
                self.server_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.server_process.kill()

    def request(
        self, method: str, path: str, payload: dict[str, Any] | None = None
    ) -> tuple[int, dict[str, Any]]:
        data = json.dumps(payload).encode("utf-8") if payload is not None else None
        request = urllib.request.Request(f"{self.base_url}{path}", data=data, method=method)
        request.add_header("Accept", "application/json")
        if payload is not None:
            request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                body = response.read().decode("utf-8", "replace")
                return response.status, json_body(body)
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", "replace")
            return exc.code, json_body(body)
        except urllib.error.URLError:
            return 0, {}

    @staticmethod
    def error_code(response: dict[str, Any]) -> str | None:
        value = response.get("value")
        if isinstance(value, dict):
            return value.get("error")
        return None

    @staticmethod
    def error_message(response: dict[str, Any]) -> str | None:
        value = response.get("value")
        if isinstance(value, dict):
            return value.get("message")
        return None


def json_body(body: str) -> dict[str, Any]:
    if not body:
        return {}
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        return {"value": {"message": body}}
    return data if isinstance(data, dict) else {"value": {"message": body}}


if __name__ == "__main__":
    try:
        main()
    except RunnerError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
