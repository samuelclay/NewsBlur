---
name: commit-pr
description: >-
  Use when the user runs /commit-pr, says "commit and push", "open a PR",
  "ship this", asks to update an existing PR with new changes, or asks to
  resolve PR review comments in the NewsBlur repo. Commits, opens or updates
  the PR, pre-flights what CI runs, then stays on the PR until it is verifiably
  clean: marked ready for review, green required checks, and zero unresolved
  Claude/Codex review threads on the current head. Other skills (investigate-forum)
  call this for the push-to-clean-PR loop instead of repeating it.
---

# /commit-pr

Commit pending changes and open or update a PR, then watch CI and the automated review bots through to green and resolved. Adapted for NewsBlur from the Tavus skillshare `commit-pr` skill; the CI and review-thread loop is the same, the repo specifics are NewsBlur's.

## Goal: what "done" means

The goal is a **verified-clean PR**, not a pushed branch. Immediately before ending the turn, re-run the live checks and confirm all of the following on the **current head SHA**:

1. Every required check is green (`gh pr checks`).
2. Zero unresolved Claude/Codex review threads (the GraphQL query in section 6, run fresh; never trust a result from before the last push).
3. The PR is marked **ready for review**. Draft is this skill's starting state, never its ending state, unless the user explicitly asked for a draft in this run.

Review-task state, not a fixed delay, decides when the review wait is over. Ending the turn while a review workflow is queued or running, or while an unresolved automated review thread exists, is a failure of this skill. If no review check is pending for the current head, run the final thread query immediately; do not wait out a timer. Every wait is on a known action: each pending check belongs to a workflow whose recent run durations are queryable (section 5), so size the wait from that record, never from a guessed interval.

If genuinely blocked (a review check is stuck, CI is broken by something outside this PR, a comment needs a decision only Sam can make), end the turn by stating exactly what is unresolved and why. Never imply the PR is clean when the final verification did not run or did not pass.

## NewsBlur specifics

| Thing | Value |
|---|---|
| Repo | `samuelclay/NewsBlur`, default branch `main` |
| PR template | none; use the body the caller supplies, else the generic default at the bottom |
| CI on pull requests | `tests.yml` (Django Tests, job `test`), `ios-actions.yml` (iOS Tests), `android-actions.yml` (Android Tests) |
| Review bots on pull requests | `claude-pr-review.yml` (Claude PR Review) and `codex-pr-review.yml` (Codex PR Review); both run on open, reopen, ready_for_review, and every synchronize |
| Commit subjects | Plain imperative sentence, no conventional prefix (`Fix`, `Add`, `Never ration ...`). Match `git log --oneline -10`. |
| Commit trailers | The attribution lines from the current session's system reminder (`Co-Authored-By`, `Claude-Session`) |
| PR footer | `🤖 Generated with [Claude Code](https://claude.com/claude-code)` then the session URL, per the session reminder |
| Labels | Whatever the caller asks for (`forum` for forum-triage PRs) |
| Python style | Black line length 110, isort profile black, flake8 |
| Tests | Run inside Docker: `docker exec -t newsblur_web[_<worktree>] python manage.py test <scope> --noinput -v 1`. Never a local Python. |
| Worktrees | Feature work lives in `.worktree/<branch>` with containers `newsblur_*_<branch>`; see CLAUDE.md |

## Workflow

### 0. Identify where you are and what CI will check

```bash
git rev-parse --show-toplevel
git branch --show-current
ls .github/workflows/
```

Cache these for the run. If the branch is `main`, stop: propose a branch name and create it before committing (see Notes).

**Visual evidence for UI changes.** If the change is visible on screen, capture before/after screenshots and attach them with `gh pr create --attach 'path.png#Alt text'` (or `gh pr edit --attach` on an existing PR; gh 2.99+ uploads and rewrites the body). For a web change the headless helper `.agents/skills/investigate-forum/screenshot.py` captures a logged-in worktree stack without a browser; the claude-in-chrome tools work too when Sam has asked for browser use. Backend-only PRs show the failing-then-passing test output instead.

### 1. Pre-flight: run what CI runs

Django Tests runs `python manage.py test apps` (see `tests.yml`); locally run the modules the diff touches, from the worktree's own web container:

```bash
docker exec -t newsblur_web_<worktree> python manage.py test apps.<app>.<module>.<TestClass> --noinput -v 1
docker exec -t newsblur_web_<worktree> sh -c "black --check --line-length 110 <changed .py files>; isort --check-only --profile black <changed .py files>; flake8 --max-line-length 110 --select=E9,F63,F7,F82,F821 <changed .py files>"
```

If the worktree stack is stopped, `make worktree` from the worktree brings it back. iOS and Android changes follow the build commands in CLAUDE.md and `clients/ios/CLAUDE.md`; at minimum the compile-only check must pass. Fix failures before committing.

### 2. Stage and commit

Group modified files by logical change into separate commits. Stage specific files per commit, not `git add -A`, so stray files never ride along. Subject: one imperative sentence that says what changes for a user or reader, with the forum topic in parentheses when there is one, for example `Never ration a forbidden feed shared by active readers by their proxy budget (forum #13832)`. Body: why, wrapped at 72 characters, then the attribution trailers. Make all commits first, then push once.

### 3. Push

```bash
git push -u origin "$(git branch --show-current)"    # first push
git push                                             # after that
```

If the branch is behind `main`, rebase (`git pull --rebase origin main`), never merge. Never force-push a PR branch unless Sam explicitly asks.

### 4. Create or update the PR

```bash
gh pr view --json number,title,url,isDraft 2>/dev/null
```

**No PR yet:** create it as a draft with the caller's body (or the generic default below), title equal to the main commit subject, at most 70 characters, no trailing period, and any requested labels:

```bash
gh pr create --draft --label forum --title "<title>" --attach "screenshots/before.png#Before" --attach "screenshots/after.png#After" --body "$(cat <<'EOF'
<body>
EOF
)"
```

Draft keeps early CI churn out of the review queue; section 5.5 promotes it in this same run.

**PR exists:** the push already updated it. Edit the body only if the scope changed (`gh pr edit <n> --body ...`).

Write the body for a reviewer walking in cold: what changed and why, what to check, exact test commands with before and after output, deploy notes (`make deploy`, `make celery`, or both; migrations; Celery restart). Cut author process notes.

### 5. Watch CI

```bash
gh pr checks --watch
```

Size waits from the workflows' own history, not a guessed timer:

```bash
gh run list --workflow=tests.yml --status completed --limit 5 --json startedAt,updatedAt,conclusion
```

Run the watch in the background or check back near the expected finish; check state ends the wait, never elapsed time. Never end the turn while a check is queued or running.

If a check fails:

1. Read the log: `gh run view <run-id> --log-failed | grep -E "FAIL:|ERROR:|Traceback|AssertionError|FAILED \("`.
2. Classify: a regression from this PR (fix it); a failure that is also red on `main` at the merge base (`gh run list --branch main --limit 10 --json name,conclusion,headSha`), which is fixed when small and self-contained, such as a test that depends on DNS or a missing mock, and otherwise reported; or a transient failure (network, runner), which gets `gh run rerun <run-id> --failed`.
3. Fix locally, repeat the pre-flight, commit as a new focused commit, push. Never amend or force-push to fix CI on an open PR.
4. Watch again.

Known NewsBlur failure mode: `test_*_records_no_error` style tests in `Test_ScrapingBeeProxy` fail on the GitHub runner when a test feed's hostname cannot be resolved, because `FetchFeed.fetch` records a 401 before the path under test. The fix is `@patch("utils.feed_fetcher.validate_public_url")` on the test.

Local gate before every push that touches `apps/rss_feeds/models.py`, `apps/reader/models.py`, or `utils/feed_fetcher.py`: the full `apps` suite, not just the touched module, since those files reach every app. Run it in the foreground (a run started with `run_in_background` is killed under host memory pressure; a foreground run that outlives its window is moved to the background and survives). Never run two test invocations against the same worktree at once: they collide on the test database and the second stalls on `DROP DATABASE`. Stop the worktree stack (`make worktree-stop`) while waiting on CI and start it again for the next round.

The Django CI job aborts the test step at 7 minutes (`timeout --signal=ABRT 420`). The suite takes 3 to 4 minutes on a normal runner and the faulthandler dump shows where it was; if the abort hit the suite still progressing normally, the runner was slow: rerun once before looking for a cause.

The Claude review check (`claude-review`) currently fails on every PR before any model output (`is_error:true`, one turn, zero cost: its API call is rejected). The action also skips itself on any PR that changes its own workflow file, so a workflow fix only shows on the next PR after it merges. Report it, do not chase it, and do not treat it as a blocker when Sam says the rest is green.

### 5.5 Promote the draft, same run

As soon as every required check on the current head is green:

```bash
gh pr ready <number>
```

Promotion is on this run's critical path. The review bots skip drafts, so marking ready is what starts their first run; the fix pushes that follow trigger them again through `synchronize`. Two exceptions: Sam asked for a draft this run, or CI cannot reach green because of a blocker outside this PR (report it, do not promote a red PR).

### 6. Wait for the Claude and Codex reviews and clear their threads

After **every** push that changes the head SHA, inspect the checks on that head:

```bash
gh pr checks --json name,workflow,bucket,state,link
```

`Claude PR Review` and `Codex PR Review` are the automated review tasks. While either has `bucket: pending`, wait for it the way section 5 waits (their recent durations come from `gh run list --workflow=claude-pr-review.yml` and `codex-pr-review.yml`; Codex normally takes 3 to 9 minutes). When neither is pending for the current head, the review wait is over: query the threads once more and handle what they posted.

Review threads, not flat PR comments, are the source of truth. New threads are appended, so query the tail (`last: 100`); with `first: 100` a PR that reaches its hundred-and-first thread hides every new one, which happened on #2133 at exactly 100.

```bash
PR=$(gh pr view --json number -q .number)
gh api graphql -F owner=samuelclay -F repo=NewsBlur -F number="$PR" -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(last: 100) {
        totalCount
        nodes {
          id
          isResolved
          comments(first: 20) { nodes { databaseId author { login } body path line url } }
        }
      }
    }
  }
}'
```

Unresolved threads whose author is a bot (`github-actions[bot]`, `claude[bot]`) or whose body names Claude or Codex are the ones to clear. If Sam asked to resolve all comments, include human threads too.

For each actionable thread:

1. Read the comment and the surrounding code.
2. Fix it locally with the smallest reasonable change, or decide it is wrong or stale.
3. Re-run the pre-flight plus any test tied to the comment.
4. Commit the fix as a new focused commit. Batch the fixes for all open threads into as few commits as make sense, then push once.
5. Reply with what changed and which test covers it (the reviewer's next round reads it), then resolve the thread. The reply goes into the thread through the REST endpoint with the first comment's `databaseId`; `gh api` takes no `-R` flag:

```bash
gh api repos/samuelclay/NewsBlur/pulls/$PR/comments -F in_reply_to="$COMMENT_DATABASE_ID" -f body="Fixed in <sha>. ..."
gh api graphql -f id="$THREAD_ID" -f query='
mutation($id: ID!) { resolveReviewThread(input: { threadId: $id }) { thread { id isResolved } } }'
```

Resolve without a code change only when the comment is wrong, stale, or already addressed by the current diff, and say why in a short reply. A comment that needs a product decision goes to Sam through AskUserQuestion; do not guess.

After any follow-up push, repeat the review-task check for the new head, wait only while a review task is pending, then `gh pr checks --watch` again.

**Round cap.** Three review rounds per PR. If the fourth round opens new threads, stop and ask Sam with AskUserQuestion, with the size of the PR next to the size of its first commit, whether to continue, split the PR, or merge with the new findings as follow-up issues. Ask sooner when a round's findings are all second-order races in code this PR itself introduced (a bug fix that has grown locks, leases, queues, or a new store is a subsystem, which is a product decision, not a review thread). Codex at medium thinking (its setting since #2136) keeps finding a real but ever finer edge on a growing surface; #2133 ran seventeen rounds and 102 threads before Sam called it, and the loop was not converging. When Sam closes the loop, say so in the PR body's review section so the next reader knows further findings are follow-ups.

**Final verification, mandatory, immediately before ending the turn:** re-run the thread query and `gh pr checks` against the current head and confirm the Goal holds. If not, keep working or report the blocker explicitly.

## When Sam says merge

Only when Sam says so in that session; the skill never merges on its own. The repo uses merge commits, not squashes.

1. Order: workflow and bot PRs first, then the rest oldest first. Check whether Sam already merged one (`gh pr view N --json state,mergedBy`); a commit pushed to a branch after its PR merged is not on `main` and needs its own PR.
2. `gh pr merge N --merge`. When GitHub answers that the merge commit cannot be created, bring the branch up to date in its worktree with `git merge origin/main` (a merge, not a rebase: the branch has been reviewed as it is), resolve, run the touched app's suite (the full `apps` suite when models or the fetcher changed), push, then merge.
3. Two PRs that both inserted test classes at the same spot conflict in the test file only, with git interleaving the classes: keep our side of every hunk, re-insert `main`'s new top-level classes whole, and check the merged file's class set is the union of both parents and that a class edited on both sides ends up as `main`'s superset.
4. After the last merge: stop the worktree stacks, and tell Sam what is merged but not deployed and which post-deploy steps (migrations, data scripts) the forum replies assume.

## Generic default body (when the caller supplies none)

```markdown
## Summary

<1 to 3 bullets: what changed and what behavior reviewers should expect>

## Context

<What was true before this PR, who it affected, and any forum topic, issue, or constraint a reviewer needs before reading the diff>

## Test plan

- [ ] <exact command and result>
- [ ] <before/after evidence>

## Deploy notes

<make deploy, make celery, or both; migrations; Celery restart>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

<session url>
```

## Notes for the agent

- **Never push to `main`.** If on `main`, create a branch (`<short-description>` or `forum-<id>-<slug>` for forum work) before committing.
- **Never use `--no-verify`** and never force-push a PR branch unless Sam explicitly asks.
- **One PR, one logical change.** Two unrelated changes in the tree means asking Sam whether to split them.
- **Report outcomes faithfully.** If a check failed and could not be fixed, say which one and link it. If the review wait was skipped because no review check exists on this repo yet, say so.
