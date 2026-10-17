#!/usr/bin/env python3
"""Run F-Droid's source scanner against a disposable Android source export."""

import argparse
import json
import sys

from fdroidserver import common, metadata, scanner


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="Disposable source tree, with app/src/play removed")
    args = parser.parse_args()
    # check_fdroid_source.py uses the same scanner and Gradle mode as fdroid build.
    common.options = argparse.Namespace(verbose=False, json=True)
    common.get_config()
    build = metadata.Build()
    build.gradle = ["yes"]
    messages = scanner.MessageStore()
    problems = scanner.scan_source(args.source, build, messages)
    print(
        json.dumps(
            {"fatalProblems": problems, "errors": messages.errors, "warnings": messages.warnings}, indent=2
        )
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
