---
name: deslopify-tests
description: >-
  Delete NewsBlur tests that cannot catch a real bug, proving each deletion by
  breaking the code and rerunning the suite in the web container, and keep the
  test rules in AGENTS.md current. Review mode checks only the tests a diff
  adds or changes; commit-pr runs it before committing.
argument-hint: "[prune [path ...] | review [base]] [report-only]"
---

# Deslopify tests

Agents write tests after the code, from reading the code, so the tests restate it. They always pass, catch almost nothing, and break on every refactor. This skill removes those tests and keeps agents from writing new ones. Adapted for NewsBlur from the Tavus skillshare `deslopify-tests` skill, which follows a thread by [dex](https://x.com/dexhorthy/status/2101336491620470826), [Ansh Nanda](https://x.com/anshnanda/status/2101627891721371971), and [Ray Fernando](https://x.com/RayFernando1337/status/2102927565778522610). The bar and the proof are the same; the commands, lanes, and protected areas are NewsBlur's, in [references/newsblur.md](references/newsblur.md).

## Modes

- **review**: check only the test cases the current diff adds or changes, against `origin/main` or the base given. `commit-pr` runs this before it commits a diff that touches tests.
- **prune** (default when called by name with no mode): check every Django test case in the repo, or in the paths given, and delete the ones that fail the bar. Ends with a PR that `commit-pr` takes to ready for review. Ask Sam with AskUserQuestion before starting a whole-repo prune: it takes hours and nothing else can run tests meanwhile.
- **report-only**, with either mode: write the ledger and change nothing.

## Goal: what done means

Review is done when every added or changed test case has a named bug and a mutation result, and each case that fails the bar is deleted or rewritten before the commit.

Prune is done when every in-scope test case has one decision, every deletion has a mutation result from `scripts/mutate.py`, the Django Tests lane passes locally after the deletions, and a PR carrying the ledger is ready for review per `commit-pr`.

## The bar

A test case stays only when both are true:

1. **It catches a realistic bug.** You can name a behavior change someone could ship that makes it fail: a wrong branch, an off-by-one, a dropped field, the wrong order, a missing dedupe, a swallowed error, a premium check that no longer runs. Editing the literal the test copies, renaming, reformatting, or a deliberate copy or prompt edit is not a bug.
2. **Nothing else catches it.** No other test that CI runs fails on the same bug.

These usually fail rule 1: constant or prompt mirrors, mock echo (asserting a mock received what the test handed it), tests of one-line wrappers, presentation checks (class names, layout, static copy), and snapshots with no behavior contract.

In scope: the Django tests under `apps/`. Out of scope: the iOS and Android suites, and anything that needs a device or a live third party. Node tests are judged by hand; see the reference.

Never deleted, even when they fail the bar:

- **Security and money boundaries**: authentication, premium and archive gating, payments and receipts, SSRF checks, sharing and privacy permissions, migration safety. One mutation is thin evidence for a boundary that has to hold against every change. `resolve --protect` keeps the ones a pattern can see; read the rest yourself before deleting. The PR lists every kept case that failed the bar for Sam to decide.
- **Shipped-bug locks**: a case whose name, comment, or docstring cites a forum topic, a Sentry issue, a regression, or "Bug:", and any test added by a fix commit. The Bug Fixing Workflow in CLAUDE.md produces these on purpose.

Don't simplify a shared helper while deleting: dropping a parameter that only the deleted cases passed makes the case hard to restore.

A test file that no CI lane collects protects nothing today. Apply the bar to it anyway, and list the kept ones in the PR as "not run in CI".

## The proof: break it and rerun

Reading alone never deletes a test. Every deletion needs a mutation result.

For each candidate case:

1. **Name the bug**: the rule the case claims to protect, and the realistic change most likely to make it fail. Pick the bug the case's own name and assertions point at. A weak or unrelated bug turns a good test into false slop.
2. **Apply it to the code under test**, never to the test. Keep the code importable: a syntax or import error proves nothing.
3. **Run the related tests with the bug in place**: the candidate's module plus every CI-run module that could plausibly catch it.
   - The candidate still passes, and the bug is shown to take effect: **slop**.
   - The candidate still passes, but nothing shows the bug took effect: **unproven**, and the case stays.
   - The candidate fails and another test fails too: **redundant**.
   - Only the candidate fails: **keep**.
4. **Restore the code** before the next case.

A passing candidate proves nothing on its own. A guard elsewhere can mask the bug, so the code the test runs behaves the same. The bug counts as having taken effect when another test fails on it, or when a **probe** makes the candidate fail. A probe is an edit at the same spot, applied instead of the bug: a raise inside the branch or expression the bug changes, or, for a constant the test reads, removing the text the test copies. A raise at the top of the function doesn't count when the bug changes one expression deep inside it.

A failing neighbour can be fake too. When the bug makes the candidate fail before its cleanup, the rows it leaks into the shared test databases can fail other tests in the same run. Give each spec line an `isolate_cmd` that excludes the candidate; a catcher then counts only if it fails on its own. For results already run without one, `scripts/mutate.py isolate-spec <shard dir>` writes `-i` recheck lines.

`scripts/mutate.py run` does steps 2 to 4 from a JSONL spec (its docstring has the fields). It runs a baseline once per command, reads the JUnit report that `scripts/django_junit.py` writes, ignores tests already red at baseline, confirms a redundant verdict on a second run so one flaky failure can't justify a deletion, and restores every source file after each mutation. A result of `invalid` proves nothing: try a different bug once, then keep the case. A retry reuses the id with `-r`, a challenge with `-c`, and an isolation recheck with `-i`; the last result for an id wins. Keep the spec and results files in the scratch directory, not the repo; they are the repeatable artifact for the PR.

Skip the run only for a clear keep: a case with a strong, specific bug where no other test in the module or the related modules checks the same behavior. Keeping is the safe default; only deletions need proof.

The unit is the test case: one `test_*` method. `subTest` rows belong to their case.

## Review

1. List the test cases the diff adds or changes: `git diff <base>...HEAD` plus uncommitted changes.
2. For each added case, name the bug and run the proof. A test that was written first and seen to fail before the fix has its proof already: say so and move on. For each changed case, check that no assertion was weakened or dropped without a reason.
3. Slop or redundant: delete it, or rewrite it so it catches the named bug when that rule is worth guarding. Rerun.
4. Report one line per case: kept (bug and result), deleted, or rewritten.

## Prune

### 1. Scope and baseline

- Read [references/newsblur.md](references/newsblur.md). Create the prune's worktree and bring its stack up.
- Record the baseline for the Django Tests lane: files, cases, wall time, and any tests already red. Red tests on `main` are reported, not pruned.
- **Prove that mutations reach the tests.** Break one function a kept test covers and confirm that test fails through `django_junit.py`. A container that mounts a different checkout makes every mutation invisible, and every test then looks like slop.

### 2. Run the mutations

- Split the test modules into shards of about 150 to 250 cases, keeping each app together.
- Shards run **one at a time**: every checkout shares the same test databases, so mutation runs cannot overlap. Subagents can write the spec lines for several shards at once (reading tests and naming bugs needs no test run), but only one `mutate.py run` may be in flight. Each subagent returns counts and paths, never raw test output.
- Then run a separate skeptic over each shard's deletion verdicts. For slop, it asks whether a stronger realistic bug would make the case fail, and whether the probe really sits where the bug changes behavior. For redundant, it asks whether another realistic bug would fail this case but not the tests that caught the first one: a different branch, input, or field. The bar keeps a test when *any* such bug exists. If an answer is yes, it writes a `-c` spec line, and that result replaces the original. A wrongly chosen bug is the main way a good test gets deleted.
- Keep each `related_cmd` a single `django_junit.py` command. A chain (`a && b`) can't take an `--exclude`, so its redundant verdicts can't be isolated.

### 3. Resolve across shards

Run `scripts/mutate.py resolve` over every shard's results. It deletes a redundant case only while at least one test that caught its bug survives, so two tests that each cover the other are never both deleted, and it keeps every protected case. Its output is the deletion plan.

### 4. Delete

Apply the plan on the PR branch.

- Delete the planned cases and nothing else. Trim mixed files; delete a file only when no case survives.
- Remove imports, fixtures, helpers, and mocks that only the deleted cases used. Leave anything another test still uses.
- Never weaken an assertion to keep a case. Keep it as it is or delete it.
- Rerun each touched module; it must pass.

### 5. Verify

Run the full `apps` suite and the format checks from the reference. Fix breakage the deletions caused, such as a dangling import. Record the after-counts and wall time.

Then review the deletion diff the way the PR's reviewers will, with fresh subagents that see only the diff and the kept tests. For each deleted case, try to name a realistic bug the kept tests would miss: a different branch, input, or field, an idempotency or timeout path. Restore every case where one exists.

### 6. Rules

Check `AGENTS.md` against [references/rules.md](references/rules.md) and add only what is missing.

### 7. PR

Hand off to `commit-pr`. The body:

- Opens with what was removed and how each removal was proven.
- Counts before and after: files, cases, wall time. Deletions by verdict.
- What to review first: the redundant deletions.
- A "Kept for Sam to decide" section: each protected case that failed the bar, with its verdict, bug, and catchers.
- The full ledger: `scripts/mutate.py ledger plan.jsonl --out-dir <dir>` writes it as collapsed sections grouped by directory, split into files under GitHub's 65,536-character limit. Put the first file in the body if it fits, and the rest in PR comments.
- Kept tests in files CI never runs get their own list.

## Guardrails

- Never edit a test to change a mutation result. Never leave a mutation in the tree: after each run, `git status` must show only the intended changes.
- Never run two test invocations at once, in any checkout.
- Prune deletes tests and the helpers only they used. It does not refactor source code, add tests, or wire files into CI.
- `report-only` changes nothing.
- Never merge. Sam reviews the ledger before anything lands.
