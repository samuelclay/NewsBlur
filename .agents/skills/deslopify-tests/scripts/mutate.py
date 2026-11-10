#!/usr/bin/env python3
"""Break the code, rerun the tests, and decide which test cases earn their place.

Copied from the Tavus skillshare deslopify-tests skill and adapted for NewsBlur:
Django tests report through django_junit.py, and isolation uses its --exclude.

  mutate.py run SPEC.jsonl [--out RESULTS.jsonl] [--dry-run]
  mutate.py resolve RESULTS.jsonl [RESULTS.jsonl ...] [--protect REGEX] > PLAN.jsonl
  mutate.py ledger PLAN.jsonl --out-dir DIR
  mutate.py isolate-spec SHARD_DIR [--prefix CMD] > RECHECK.jsonl

`run` reads a JSONL spec, one mutation per line:
  id           unique string
  bug          one line: the realistic bug the edits introduce
  edits        [{"file": source path, "find": exact text, "replace": text}]
               applied to source code only; each "find" must occur exactly once;
               paths are relative to cwd when it is set
  candidate    {"file": test file path, "name": test case name}
               Django: "test_fn" or "Test_Class::test_fn"
               node --test: the test title
  related_cmd  shell command that runs the candidate's file plus every other
               test that could catch the bug; "{junit}" is replaced with a
               JUnit XML report path
  probe        optional edits, applied instead of the bug, that must make the
               candidate fail: a raise inside the branch the bug changes, or,
               for a constant the test reads, removing the text it copies.
               It proves the candidate runs the code the bug changed.
  isolate_cmd  optional related_cmd variant that excludes the candidate (for
               Django, add --exclude <test id>). When set, a catcher must also
               fail in this run, so a test that fails only on state the failing
               candidate leaked (database rows, module globals) doesn't count.
  cwd          optional working directory for the command
  timeout      optional seconds (default 900)

and prints one result per line with a verdict:
  slop       the candidate still passes with the bug in place, and the bug is
             shown to take effect: another test fails on it, or the probe
             makes the candidate fail
  unproven   the candidate still passes, but nothing shows the bug took effect;
             a guard elsewhere may mask it, so the case is kept
  redundant  the candidate fails, and another test that passed at baseline fails
             too, on two separate runs with the bug in place (the second one
             without the candidate when isolate_cmd is set)
  keep       the candidate fails and nothing else does
  invalid    the result proves nothing: candidate red or missing at baseline,
             a find that does not match once, a timeout, or a run that failed
             on import, syntax, or collection errors

Source files are restored after every mutation, including on error, Ctrl-C,
and SIGTERM.

`resolve` merges results from every shard and prints the deletion plan. When
a retry ("<id>-r"), a challenge ("<id>-c"), or an isolation recheck ("<id>-i")
reruns a case, the last result for that id wins. A redundant test is deleted
only while at least one test that caught its bug survives, so two tests that
each cover the other are never both deleted. Cases whose file, name, or JUnit id
(which carries the module and class names) matches --protect are never deleted.
The default covers security boundaries (auth, secrets, redaction, SSRF and
origin checks, signatures, sandboxing, injection filtering, data retention) and
names that cite an incident, ticket, regression, or outage.
The plan marks those cases "keep", reason "protected", for a person to review.

`isolate-spec` turns a shard's redundant verdicts from django_junit.py runs
into "<id>-i" spec lines that rerun with an isolate_cmd excluding the candidate. --prefix is
prepended to both commands, for example a database reset.

`ledger` renders the plan's deletions as markdown for the PR, grouped by
directory and split into files under GitHub's 65,536-character comment limit.
"""

import argparse
import json
import re
import signal
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
from pathlib import Path

BROKEN_RUN = re.compile(
    r"SyntaxError|IndentationError|ImportError|ModuleNotFoundError|collection failure"
    r"|Failed to load url|Failed to resolve import|Transform failed|Failed to parse source"
)


def read_junit(path):
    cases = []
    for tc in ET.parse(path).getroot().iter("testcase"):
        status, message = "passed", ""
        for child in tc:
            if child.tag in ("failure", "error"):
                status = "failed"
                message = (child.get("message") or "") + "\n" + (child.text or "")
            elif child.tag == "skipped" and status == "passed":
                status = "skipped"
        cases.append(
            {
                "classname": tc.get("classname", ""),
                "file": tc.get("file", ""),
                "name": tc.get("name", ""),
                "status": status,
                "message": message[:4000],
            }
        )
    return cases


def case_id(tc):
    return f"{tc['classname']}::{tc['name']}"


def is_candidate(tc, candidate):
    stem = Path(candidate["file"]).name.split(".")[0]
    if stem not in f"{tc['classname']} {tc['file']}":
        return False
    name = candidate["name"]
    if "::" in name:
        cls, name = name.rsplit("::", 1)
        if not tc["classname"].endswith("." + cls.split("::")[-1]):
            return False
    n = tc["name"]
    return n == name or n.startswith(name + "[") or n.endswith(" > " + name)


def run_tests(cmd, cwd, timeout):
    with tempfile.TemporaryDirectory() as tmp:
        junit = str(Path(tmp) / "junit.xml")
        started = time.monotonic()
        try:
            proc = subprocess.run(
                cmd.replace("{junit}", junit),
                shell=True,
                check=False,
                cwd=cwd,
                timeout=timeout,
                capture_output=True,
                text=True,
            )
        except subprocess.TimeoutExpired:
            return {"error": f"timeout after {timeout}s"}
        seconds = round(time.monotonic() - started, 1)
        if not Path(junit).exists():
            tail = (proc.stdout + proc.stderr)[-1500:]
            return {"error": f"no JUnit report (exit {proc.returncode}): {tail}"}
        cases = read_junit(junit)
        failed = [c for c in cases if c["status"] == "failed"]
        if proc.returncode != 0 and not failed:
            tail = (proc.stdout + proc.stderr)[-1500:]
            return {"error": f"exit {proc.returncode} with no failing test: {tail}"}
        return {"cases": cases, "seconds": seconds}


def apply_edits(edits, cwd=None):
    originals = {}
    try:
        for edit in edits:
            path = Path(cwd or ".") / edit["file"]
            if not path.is_file():
                raise ValueError(f"{path}: no such file")
            if path not in originals:
                originals[path] = path.read_bytes()
            text = path.read_text()
            count = text.count(edit["find"])
            if count != 1:
                raise ValueError(
                    f"{path}: find text occurs {count} times, needs exactly 1"
                )
            path.write_text(text.replace(edit["find"], edit["replace"]))
    except BaseException:
        restore(originals)
        raise
    return originals


def restore(originals):
    for path, data in originals.items():
        path.write_bytes(data)


def check(spec, baselines):
    key = (spec.get("cwd"), spec["related_cmd"])
    timeout = spec.get("timeout", 900)
    if key not in baselines:
        baselines[key] = run_tests(spec["related_cmd"], spec.get("cwd"), timeout)
    base = baselines[key]
    if "error" in base:
        return {"verdict": "invalid", "note": f"baseline run failed: {base['error']}"}
    base_candidate = [c for c in base["cases"] if is_candidate(c, spec["candidate"])]
    if not base_candidate:
        return {"verdict": "invalid", "note": "candidate not found in the baseline run"}
    if any(c["status"] != "passed" for c in base_candidate):
        return {"verdict": "invalid", "note": "candidate is not green at baseline"}
    base_red = {case_id(c) for c in base["cases"] if c["status"] == "failed"}

    after = run_mutated(spec, timeout)
    if "error" in after:
        return {"verdict": "invalid", "note": after["error"]}
    failed = [c for c in after["cases"] if c["status"] == "failed"]
    if any(
        BROKEN_RUN.search(c["message"]) for c in failed if case_id(c) not in base_red
    ):
        return {
            "verdict": "invalid",
            "note": "the bug broke import, syntax, or collection",
        }
    candidate = [c for c in after["cases"] if is_candidate(c, spec["candidate"])]
    if not candidate:
        return {"verdict": "invalid", "note": "candidate did not run"}
    others = [
        case_id(c)
        for c in failed
        if not is_candidate(c, spec["candidate"]) and case_id(c) not in base_red
    ]
    result = {
        "candidate_ids": [case_id(c) for c in candidate],
        "seconds": after["seconds"],
    }
    if all(c["status"] == "passed" for c in candidate):
        result["caught_by"] = others
        if others:
            return {
                **result,
                "verdict": "slop",
                "evidence": "other tests fail on the bug",
            }
        if not spec.get("probe"):
            return {
                **result,
                "verdict": "unproven",
                "note": "nothing shows the bug took effect; add a probe",
            }
        probed = run_mutated({**spec, "edits": spec["probe"]}, timeout)
        if "error" in probed:
            return {
                **result,
                "verdict": "unproven",
                "note": f"probe run failed: {probed['error']}",
            }
        hit = [
            c
            for c in probed["cases"]
            if is_candidate(c, spec["candidate"]) and c["status"] == "failed"
        ]
        if hit and not any(BROKEN_RUN.search(c["message"]) for c in hit):
            return {
                **result,
                "verdict": "slop",
                "evidence": "the probe makes the candidate fail",
            }
        return {
            **result,
            "verdict": "unproven",
            "note": "the probe did not make the candidate fail",
        }
    if others:
        # A flaky test that happens to fail once would make the candidate look
        # redundant, so a catcher has to fail on a second run too.
        second = spec
        if spec.get("isolate_cmd"):
            second = {**spec, "related_cmd": spec["isolate_cmd"]}
            key = (spec.get("cwd"), spec["isolate_cmd"])
            if key not in baselines:
                baselines[key] = run_tests(
                    spec["isolate_cmd"], spec.get("cwd"), timeout
                )
            if "error" in baselines[key]:
                return {
                    **result,
                    "verdict": "invalid",
                    "note": f"isolated baseline failed: {baselines[key]['error']}",
                }
        again = run_mutated(second, timeout)
        if "error" in again:
            return {
                **result,
                "verdict": "invalid",
                "note": f"confirmation run failed: {again['error']}",
            }
        red_again = {case_id(c) for c in again["cases"] if c["status"] == "failed"}
        others = [o for o in others if o in red_again]
    return {**result, "caught_by": others, "verdict": "redundant" if others else "keep"}


def run_mutated(spec, timeout):
    originals = {}
    try:
        originals = apply_edits(spec["edits"], spec.get("cwd"))
        return run_tests(spec["related_cmd"], spec.get("cwd"), timeout)
    except ValueError as err:
        return {"error": str(err)}
    finally:
        restore(originals)


def cmd_run(args):
    specs = [
        json.loads(line)
        for line in Path(args.spec).read_text().splitlines()
        if line.strip()
    ]
    baselines = {}
    out_path = Path(args.out) if args.out else None
    for spec in specs:
        if args.dry_run:
            try:
                restore(apply_edits(spec["edits"], spec.get("cwd")))
                result = {"verdict": "applies"}
            except ValueError as err:
                result = {"verdict": "invalid", "note": str(err)}
        else:
            result = check(spec, baselines)
        line = json.dumps(
            {
                "id": spec["id"],
                "candidate": spec["candidate"],
                "bug": spec.get("bug"),
                **result,
            }
        )
        print(line, flush=True)
        if out_path:
            with out_path.open("a") as out:
                out.write(line + "\n")


PROTECT = (
    r"(?i)(auth|token|secret|scrub|redact|permission|access|owner|wrong_user|other_user|forbidden"
    r"|denied|unauthori|unauthenticat|\b40[13]\b|_40[13]|admin|ssrf|private_|hostname|origin"
    r"|cors|csrf|hmac|signature|signed|hash|inject|sanitiz|sandbox|leak|credential|password"
    r"|api_?key|allowlist|blocklist|net_guard|rate_limit|retention|zdr|pii|encrypt|jwt|oauth|m2m"
    r"|security|tenant|cross_account|impersonat|xss|traversal|cookie|bearer|captcha|turnstile"
    r"|spoof|x.forwarded|sec.fetch|fetch.metadata|url.?scheme|javascript:|custodial"
    r"|premium|archive_tier|is_pro|paypal|stripe|payment|refund|receipt|subscription|billing"
    r"|validate_public_url|private_ip|share_permission|migration_safety"
    r"|incident|regression|outage|lockout|forum ?#?\d+|sentry|\bBug:)"
)


def base_id(result_id):
    return re.sub(r"(-[rci])+$", "", result_id)


def cmd_resolve(args):
    latest = {}
    for path in args.results:
        for line in Path(path).read_text().splitlines():
            if line.strip():
                r = json.loads(line)
                latest[base_id(r["id"])] = r
    results = list(latest.values())
    order = {"slop": 0, "redundant": 1}
    candidates = sorted(
        (r for r in results if r["verdict"] in order),
        key=lambda r: (order[r["verdict"]], -len(r.get("caught_by", []))),
    )
    protect = re.compile(args.protect) if args.protect else None
    deleted, deleted_redundant, plan = set(), [], {}
    for r in candidates:
        ids = set(r["candidate_ids"])
        where = " ".join([r["candidate"]["file"], r["candidate"]["name"], *ids])
        if protect and protect.search(where):
            plan[r["id"]] = (
                "keep",
                "protected: security boundary, left for a person to review",
            )
            continue
        survivors = set(r.get("caught_by", [])) - deleted - ids
        if r["verdict"] == "redundant" and not survivors:
            plan[r["id"]] = (
                "keep",
                "every test that caught its bug is already being deleted",
            )
            continue
        stranded = [
            d["id"]
            for d in deleted_redundant
            if not (set(d["caught_by"]) - deleted - ids)
        ]
        if stranded:
            plan[r["id"]] = (
                "keep",
                f"last test catching the bug behind {', '.join(stranded)}",
            )
            continue
        deleted |= ids
        if r["verdict"] == "redundant":
            deleted_redundant.append(r)
        plan[r["id"]] = ("delete", r["verdict"])
    for r in results:
        decision, reason = plan.get(r["id"], ("keep", r["verdict"]))
        print(json.dumps({**r, "decision": decision, "reason": reason}))


def cmd_ledger(args):
    rows = [
        json.loads(line)
        for line in Path(args.plan).read_text().splitlines()
        if line.strip()
    ]
    deleted = sorted(
        (r for r in rows if r.get("decision") == "delete"),
        key=lambda r: (r["candidate"]["file"], r["candidate"]["name"]),
    )
    by_dir = {}
    for r in deleted:
        by_dir.setdefault(str(Path(r["candidate"]["file"]).parent), []).append(r)

    def cell(text):
        return str(text or "").replace("|", "\\|").replace("\n", " ")

    def row(r):
        c = r["candidate"]
        if r["verdict"] == "slop":
            how = (
                "; the probe shows it runs that code"
                if r.get("evidence", "").startswith("the probe")
                else ", which other tests catch"
            )
            result = f"still passed with the bug in place{how}"
        else:
            caught = r.get("caught_by", [])
            more = f" and {len(caught) - 1} more" if len(caught) > 1 else ""
            result = f"also caught by `{cell(caught[0])}`{more}"
        return f"| `{cell(Path(c['file']).name)}` {cell(c['name'])} | {cell(r.get('bug'))} | {result} |"

    header = ["", "| Test case | Bug applied | Result |", "| --- | --- | --- |"]
    sections = []
    for directory, group in by_dir.items():
        rows_md = [row(r) for r in group]
        parts, current = [], []
        for line in rows_md:
            if current and sum(len(x) + 1 for x in current) + len(line) > 55000:
                parts.append(current)
                current = []
            current.append(line)
        parts.append(current)
        for i, part in enumerate(parts, 1):
            label = f", part {i} of {len(parts)}" if len(parts) > 1 else ""
            summary = f"<details><summary><code>{directory}/</code>: {len(group)} deleted{label}</summary>"
            sections.append("\n".join([summary, *header, *part, "", "</details>", ""]))

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    chunks, current = [], ""
    for section in sections:
        if current and len(current) + len(section) > 60000:
            chunks.append(current)
            current = ""
        current += section
    if current:
        chunks.append(current)
    for i, chunk in enumerate(chunks, 1):
        (out / f"ledger-{i:02d}.md").write_text(chunk)
    counts = {}
    for r in rows:
        key = f"{r.get('decision', 'keep')}:{r['verdict']}"
        counts[key] = counts.get(key, 0) + 1
    print(json.dumps({"deleted": len(deleted), "files": len(chunks), "counts": counts}))


def django_test_id(junit_id):
    classname, _, name = junit_id.partition("::")
    return f"{classname}.{name}" if classname and name else None


def cmd_isolate_spec(args):
    shard = Path(args.shard_dir)
    specs = {}
    for f in shard.rglob("*.jsonl"):
        for line in f.read_text().splitlines():
            try:
                s = json.loads(line)
            except ValueError:
                continue
            if isinstance(s, dict) and "edits" in s and "related_cmd" in s:
                specs[s["id"]] = s
    latest = {}
    for line in (shard / "results.jsonl").read_text().splitlines():
        if line.strip():
            r = json.loads(line)
            latest[base_id(r["id"])] = r
    prefix = f"{args.prefix} && " if args.prefix else ""
    skipped = 0
    for r in latest.values():
        spec = specs.get(r["id"])
        if r["verdict"] != "redundant" or (spec and spec.get("isolate_cmd")):
            continue
        if not spec or any(c in spec["related_cmd"] for c in ("|", ";", "&&")):
            skipped += r["verdict"] == "redundant"
            continue
        if "django_junit.py" not in spec["related_cmd"]:
            skipped += 1
            continue
        nodes = [django_test_id(i) for i in r.get("candidate_ids", [])]
        if not nodes or None in nodes:
            skipped += 1
            continue
        deselect = " ".join(f"--exclude '{n}'" for n in nodes)
        out = {
            **spec,
            "id": r["id"] + "-i",
            "related_cmd": prefix + spec["related_cmd"],
            "isolate_cmd": f"{prefix}{spec['related_cmd']} {deselect}",
        }
        print(json.dumps(out))
    print(
        f"{skipped} redundant verdicts skipped (no spec line, not a django_junit.py run, or a chained command)",
        file=sys.stderr,
    )


def main():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    signal.signal(signal.SIGHUP, lambda *_: sys.exit(129))
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    run = sub.add_parser("run", help="run a mutation spec")
    run.add_argument("spec")
    run.add_argument("--out", help="also append results to this JSONL file")
    run.add_argument(
        "--dry-run",
        action="store_true",
        help="check that every edit applies, run nothing",
    )
    run.set_defaults(func=cmd_run)
    resolve = sub.add_parser("resolve", help="turn shard results into a deletion plan")
    resolve.add_argument("results", nargs="+")
    resolve.add_argument(
        "--protect",
        default=PROTECT,
        help="regex of files or case names never deleted ('' to disable)",
    )
    resolve.set_defaults(func=cmd_resolve)
    iso = sub.add_parser(
        "isolate-spec", help="recheck redundant Django verdicts without the candidate"
    )
    iso.add_argument("shard_dir")
    iso.add_argument(
        "--prefix",
        help="shell command to run before each test command, e.g. a database reset",
    )
    iso.set_defaults(func=cmd_isolate_spec)
    ledger = sub.add_parser(
        "ledger", help="render the plan's deletions as markdown for the PR"
    )
    ledger.add_argument("plan")
    ledger.add_argument("--out-dir", required=True)
    ledger.set_defaults(func=cmd_ledger)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    sys.exit(main())
