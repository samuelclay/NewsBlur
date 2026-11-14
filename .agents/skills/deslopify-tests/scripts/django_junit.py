#!/usr/bin/env python3
"""Run NewsBlur's Django tests and write a JUnit XML report (django_junit.py).

mutate.py reads JUnit XML, and `manage.py test` does not write it. This runs
the same suite through utils/testrunner.py and records one <testcase> per test,
with classname `apps.<app>.<module>.<Class>` and name `<test method>`.

On the host, from the checkout whose container should run the tests:

  django_junit.py --container newsblur_web --junit report.xml \\
      [--exclude apps.app.module.Class.test_method ...] apps.app.module ...

It reruns itself inside the container (which mounts the checkout at
/srv/newsblur), copies the report out with `docker cp`, and exits with the
test run's status. --exclude drops single tests from the run, which is what
mutate.py's isolate_cmd needs.

The test databases are kept between runs, as CI does with --keepdb. Postgres
(`test_newsblur`) and Mongo (`nb_test`) are shared by every checkout and
worktree on the machine, so only one run may be in flight at a time.
"""

import argparse
import os
import subprocess
import sys
import uuid

CONTAINER_ROOT = "/srv/newsblur"
SCRIPT_IN_CONTAINER = f"{CONTAINER_ROOT}/.agents/skills/deslopify-tests/scripts/django_junit.py"


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--container", help="web container to run in, e.g. newsblur_web_<worktree>")
    parser.add_argument("--junit", required=True, help="where to write the JUnit XML report")
    parser.add_argument("--exclude", action="append", default=[], help="test id to leave out")
    parser.add_argument("--inside", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("labels", nargs="+", help="test labels, as for manage.py test")
    return parser.parse_args()


def run_on_host(args):
    if not args.container:
        sys.exit("--container is required on the host")
    report = f"/tmp/deslopify-junit-{uuid.uuid4().hex}.xml"
    command = ["docker", "exec", "-e", "PYTHONUNBUFFERED=1", args.container, "python", SCRIPT_IN_CONTAINER]
    command += ["--inside", "--junit", report]
    for test_id in args.exclude:
        command += ["--exclude", test_id]
    status = subprocess.run(command + args.labels, check=False).returncode
    copied = subprocess.run(
        ["docker", "cp", f"{args.container}:{report}", args.junit], check=False, capture_output=True
    )
    subprocess.run(["docker", "exec", args.container, "rm", "-f", report], check=False)
    if copied.returncode != 0 and status == 0:
        sys.exit(f"tests passed but no report came back: {copied.stderr.decode().strip()}")
    sys.exit(status)


def run_inside(args):
    import unittest
    import xml.etree.ElementTree as ET

    os.chdir(CONTAINER_ROOT)
    sys.path.insert(0, CONTAINER_ROOT)
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "newsblur_web.test_settings")

    import django

    django.setup()

    from utils.testrunner import TestRunner

    outcomes = []

    class RecordingResult(unittest.TextTestResult):
        def record(self, test, status, detail=""):
            outcomes.append((test.id() if hasattr(test, "id") else str(test), status, detail))

        def addSuccess(self, test):
            super().addSuccess(test)
            self.record(test, "passed")

        def addFailure(self, test, err):
            super().addFailure(test, err)
            self.record(test, "failure", self._exc_info_to_string(err, test))

        def addError(self, test, err):
            super().addError(test, err)
            self.record(test, "error", self._exc_info_to_string(err, test))

        def addSkip(self, test, reason):
            super().addSkip(test, reason)
            self.record(test, "skipped", reason)

        def addExpectedFailure(self, test, err):
            super().addExpectedFailure(test, err)
            self.record(test, "passed")

        def addUnexpectedSuccess(self, test):
            super().addUnexpectedSuccess(test)
            self.record(test, "failure", "unexpected success")

        def addSubTest(self, test, subtest, err):
            super().addSubTest(test, subtest, err)
            if err is not None:
                self.record(test, "failure", self._exc_info_to_string(err, test))

    def flatten(suite):
        for item in suite:
            if isinstance(item, unittest.TestSuite):
                yield from flatten(item)
            else:
                yield item

    excluded = set(args.exclude)

    class JUnitRunner(TestRunner):
        def get_resultclass(self):
            return RecordingResult

        def build_suite(self, *suite_args, **suite_kwargs):
            suite = super().build_suite(*suite_args, **suite_kwargs)
            if not excluded:
                return suite
            kept = self.test_suite()
            kept.addTests(test for test in flatten(suite) if test.id() not in excluded)
            return kept

    failures = JUnitRunner(verbosity=1, interactive=False, keepdb=True).run_tests(args.labels)

    # A test with a failing subtest is recorded for the subtest and again as
    # passed when it ends; the worst outcome per test wins.
    rank = {"passed": 0, "skipped": 1, "failure": 2, "error": 2}
    worst = {}
    for test_id, status, detail in outcomes:
        if test_id not in worst or rank[status] > rank[worst[test_id][0]]:
            worst[test_id] = (status, detail)

    root = ET.Element("testsuite", name="django", tests=str(len(worst)))
    for test_id, (status, detail) in worst.items():
        classname, _, name = test_id.rpartition(".")
        case = ET.SubElement(root, "testcase", classname=classname, name=name)
        if status in ("failure", "error"):
            ET.SubElement(
                case, status, message=detail.strip().splitlines()[-1] if detail.strip() else ""
            ).text = detail
        elif status == "skipped":
            ET.SubElement(case, "skipped", message=detail)
    ET.ElementTree(root).write(args.junit, encoding="utf-8", xml_declaration=True)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    arguments = parse_args()
    if arguments.inside:
        run_inside(arguments)
    else:
        run_on_host(arguments)
