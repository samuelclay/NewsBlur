#!/usr/bin/env python3

import argparse
import subprocess
import sys
from dataclasses import dataclass
from typing import Iterable, Optional


EXPECTED_ADMIN_STATE = {
    "maint": "1",
    "ready": "0",
}


@dataclass(frozen=True)
class HaproxyTarget:
    backend: str
    server: str

    @classmethod
    def from_spec(cls, spec: str) -> "HaproxyTarget":
        backend, separator, server = spec.partition("/")
        if not separator or not backend or not server:
            raise ValueError(f"Invalid HAProxy target: {spec}")
        return cls(backend=backend, server=server)

    @property
    def spec(self) -> str:
        return f"{self.backend}/{self.server}"


def parse_show_servers_state(output: str) -> dict[tuple[str, str], str]:
    states: dict[tuple[str, str], str] = {}

    for raw_line in output.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or line.isdigit():
            continue

        fields = line.split()
        if len(fields) < 7:
            continue

        backend = fields[1]
        server = fields[3]
        admin_state = fields[6]
        states[(backend, server)] = admin_state

    return states


def verify_target_states(
    targets: Iterable[HaproxyTarget],
    states: dict[tuple[str, str], str],
    expected_admin_state: str,
) -> None:
    missing_targets: list[str] = []
    mismatched_targets: list[str] = []

    for target in targets:
        key = (target.backend, target.server)
        current_state = states.get(key)
        if current_state is None:
            missing_targets.append(target.spec)
        elif current_state != expected_admin_state:
            mismatched_targets.append(f"{target.spec}={current_state}")

    if not missing_targets and not mismatched_targets:
        return

    errors: list[str] = []
    if missing_targets:
        errors.append("missing: %s" % ", ".join(missing_targets))
    if mismatched_targets:
        errors.append(
            "expected admin_state=%s but saw %s"
            % (expected_admin_state, ", ".join(mismatched_targets))
        )
    raise RuntimeError("; ".join(errors))


def run_haproxy_commands(commands: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["docker", "exec", "-i", "haproxy", "socat", "stdio", "/var/run/haproxy.sock"],
        input="\n".join(commands) + "\n",
        text=True,
        capture_output=True,
        check=False,
    )


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Batch HAProxy server state changes over one socket session.")
    parser.add_argument("state", choices=sorted(EXPECTED_ADMIN_STATE.keys()))
    parser.add_argument("targets", nargs="+", help="Backend/server specs such as app_django/happ-web-01")
    args = parser.parse_args(argv)

    try:
        targets = [HaproxyTarget.from_spec(spec) for spec in args.targets]
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    for target in targets:
        change_result = run_haproxy_commands([f"set server {target.spec} state {args.state}"])
        if change_result.returncode != 0:
            stderr = change_result.stderr.strip()
            if stderr:
                print("%s: %s" % (target.spec, stderr), file=sys.stderr)
            return change_result.returncode

    result = run_haproxy_commands(["show servers state"])
    if result.returncode != 0:
        stderr = result.stderr.strip()
        if stderr:
            print(stderr, file=sys.stderr)
        return result.returncode

    try:
        verify_target_states(
            targets,
            parse_show_servers_state(result.stdout),
            expected_admin_state=EXPECTED_ADMIN_STATE[args.state],
        )
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print("%s: %s" % (args.state, " ".join(target.spec for target in targets)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
