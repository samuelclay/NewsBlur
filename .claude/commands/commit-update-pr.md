---
description: Commit, push, create or update a pull request, and watch CI until green
---

## Your task

Commit all staged/unstaged changes, push to remote, create or update the PR, then watch CI until it finishes and fix any failures.

**Arguments provided:** {{ arguments }}

### Steps to execute

1. **Check git status** to see what changes exist:
   ```bash
   git status
   git diff --stat
   git diff --staged --stat
   ```

2. **Check for existing PR** for the current branch:
   ```bash
   gh pr view --json number,title,url,state 2>/dev/null
   ```
   - If a PR exists and is OPEN, note its URL and number - we'll update it
   - If no PR exists or it's closed/merged, we'll create a new one

3. **Stage all changes** (if there are unstaged changes):
   ```bash
   git add -A
   ```

4. **Create the commit** following the commit message conventions:
   - Run `git log --oneline -5` to see recent commit style
   - Run `git diff --staged` to understand the changes
   - Write a concise commit message summarizing the changes
   - Use the format:
     ```bash
     git commit -m "$(cat <<'EOF'
     <commit message here>

     Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
     EOF
     )"
     ```

5. **Push to remote**:
   ```bash
   git push -u origin HEAD
   ```

6. **Create or update the PR**:

   **If a PR already exists:**
   - The push already updated the PR
   - Note: "Updated existing PR: <url>"

   **If no PR exists:**
   - Create a new PR:
     ```bash
     gh pr create --title "<title>" --body "$(cat <<'EOF'
     ## Summary
     <1-3 bullet points summarizing the changes>

     ## Test plan
     - [ ] <testing checklist items>

     ---
     Generated with [Claude Code](https://claude.com/claude-code)
     EOF
     )"
     ```

7. **Watch CI and auto-fix failures** — do NOT stop after pushing. Monitor the PR's checks until every check has a terminal status (pass, fail, skipped, cancelled), and fix any failures before handing back to the user.

   **a. Poll for status.** After pushing, wait ~30s for CI to register, then:
   ```bash
   gh pr checks <PR_NUMBER>
   ```
   The first column is the check name, the second is status (`pending`, `pass`, `fail`, `skipping`, `cancelled`). Re-run this periodically. Do not chain `sleep` commands to wait — prefer `run_in_background` so you don't block, and poll by calling `gh pr checks` again on a reasonable cadence (30–60s). Keep going until no check shows `pending`.

   **b. If everything passes:** report success with the PR URL and stop.

   **c. If any check fails:**
   - Identify the failed job URL from the `gh pr checks` output (third column).
   - Grab the failure logs with:
     ```bash
     gh run view <RUN_ID> --log-failed 2>&1 | tail -200
     ```
     Extract the `<RUN_ID>` from the job URL (it's the numeric segment after `/runs/`).
   - Diagnose the root cause from the log. Distinguish between:
     - A real regression introduced by this PR → fix it.
     - A pre-existing failure on `main` unrelated to this PR → fix it if the scope is small and self-contained (like flaky test stabilization, SDK symbol guards, or missing imports). Confirm it's pre-existing by running `git log main -- <failing-file>` and checking whether the failing code was introduced before this branch.
     - A flaky/transient failure (network, timeout, resource availability) → retry by re-running the check with `gh run rerun <RUN_ID> --failed`, then resume polling.
   - Make the fix, then repeat from step 3 (stage → commit → push → watch). Keep the cycle running until CI is green. Use focused commit messages for each fix ("Fix <specific thing>") rather than amending.

   **d. If a failure is outside your ability to fix** (credentials, infra, permissions), report the failure clearly with a link and ask the user how to proceed rather than spinning indefinitely.

8. **Report the final result**:
   - Show the PR URL and whether it was created or updated
   - Show every commit hash + message pushed during this session (the original plus any CI fix commits)
   - Confirm CI is green, or explain exactly which checks failed and why if you had to stop early
