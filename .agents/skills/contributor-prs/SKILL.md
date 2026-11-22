---
name: contributor-prs
description: Rework pull requests from outside contributors into the change Sam would have written. Use when Sam says "go through the contributor PRs", "review the outside PRs", "what's waiting from contributors", "fix up this contributor's PR", or gives a PR number from someone's fork and asks to rework, finish or take it over. For each PR it confirms the problem on current main, reproduces it with evidence, interviews Sam on the design, lands the fix as commits on the contributor's branch, appends a Maintainer changes section to the PR description, and drafts the comment to the contributor. It pushes only after the diff has been read, posts a comment only after Sam approves its text, and never merges or deploys on its own.
---

# Contributor PRs

Sam runs this every few months over all open outside PRs, or on one PR at a time. The job for each PR: find the real problem, reproduce it, make the fix the one Sam would write, land it on their PR with the evidence, and leave him a comment to approve. The contributor keeps credit for the part that was theirs.

The push, CI and merge mechanics live in the `commit-pr` skill, mostly in its "Contributor PRs from forks" and "When Sam says merge" sections. This skill is the work around them.

## Ground rules

1. **Sam decides the design.** Interview him for every PR with AskUserQuestion before implementing. Put the finding in the question, give real options with the recommendation first, and expect him to pick something else about one time in five. The questions are not a formality.
2. **Verify before you tell Sam.** A claim about production, or about what a contributor's fix would break, is checked directly before it goes into a question: read the setting, read the library source, curl the public site. One run told Sam a fix would break every blurblog subdomain when a setting two files away (`REMOVE_WWW_FROM_DOMAIN`) made it correct.
3. **Their work stays visible.** Merge `main` into their branch and commit on top. No rebase, squash or force-push. Keep their PR description and append to it. Say so plainly when their approach was right.
4. **Three gates.** Push only after the lead has read the whole diff and opened every screenshot. Post a comment only after Sam has approved its exact text and Django Tests is green on the final head. Merge and deploy only when Sam says so in that session.
5. **One poster.** Exactly one agent posts each comment, and it checks the PR's last comment first. A subagent and the lead once both posted the same comment four seconds apart.
6. **Reproduce before fixing.** The failing test or the before screenshot comes first, as CLAUDE.md says.

Sam has already answered these, so don't ask again: commits on top after merging main, keep their description and append, comments drafted for his approval, fork CI runs approved after the head is reviewed.

## Step 0: Build the queue and read live state

```bash
# Every open outside PR, whatever its age. A date window here once hid a PR opened a day before the cutoff.
gh pr list --state open --search "-author:samuelclay" --limit 300 \
  --json number,title,author,createdAt,isCrossRepository,maintainerCanModify,headRefName
# Closed and merged ones since the last run, for the closed-by-author case below.
gh pr list --state closed --search "closed:>=<YYYY-MM-DD> -author:samuelclay" --limit 300 \
  --json number,title,author,state,mergedAt,closedAt
```

- **Merged, or closed as superseded or junk:** nothing to do. Say why in one line.
- **Open with `maintainerCanModify`:** rework on their branch.
- **Closed by its author with no reply, and the bug is still on main:** redo it as a new PR from a branch in the main repo. Give them `Co-Authored-By` (take the address from their PR's commits) and draft a comment for the old PR that links the new one.

Read each PR's live state now and again before every later step: `gh pr view <N> --json state,headRefOid,mergeable,comments,commits`. Contributors push and reply while the work is under way, and `main` moves fast enough to put a reviewed PR into conflict within days. A contributor who pushes back with concrete use cases gets a fresh question to Sam, not a revert.

## Step 1: Investigate, read-only

Answer these for each PR with file and line references against current `origin/main`:

1. Is the problem real on main today?
2. What is the root cause?
3. What does the contributor's diff get right, get wrong, and overbuild? Does it still merge cleanly?
4. What is the smallest fix in Sam's style, and which of their lines survive?
5. How will the before and after be shown?
6. Which decisions belong to Sam? Two or three options each, recommendation first, one line on the trade-off.

A subagent per large PR is fine here. It edits nothing and runs no tests.

## Step 2: Interview Sam

Several short rounds beat one long one. Each question stands on its own, because the dialog hides the text above it. When the choices are drafts, each option carries its full text.

## Step 3: Implement

```bash
git worktree add --detach .worktree/pr-<N>-<slug> origin/main
cd .worktree/pr-<N>-<slug> && gh pr checkout <N> -b pr-<N> && git merge origin/main
```

- Write the failing test first and keep its output. Show it failing on main, and on the contributor's head too when their fix is the thing being replaced.
- Test at the highest level that sees the behavior, then run `deslopify-tests` in review mode over every test added or changed.
- Cut what the PR doesn't need. Options with no named use go, but ask Sam before cutting one the contributor argued for.
- Conflicts with main in `localization/translations/*.json` come from both sides adding keys to sorted files. Take the union of both sides, write each file with `json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True)`, then confirm `localization/manage.py check --allow-missing` passes and `compile` changes nothing.

Evidence, by kind of change:

| Change | Evidence |
|---|---|
| Visible in the web reader | Before and after screenshots of the same story or page. When the live source no longer shows the problem, build a small local fixture and say so |
| iOS or Android UI | Screenshots on a phone and a tablet; sheets and keyboards lay out differently. Screenshot a booted simulator before using it: when it is signed in and mid-story, boot a spare of the same model and shut it down afterwards |
| API or backend only | Failing then passing test output, plus short excerpts of real requests (counts and ids, not whole payloads) |
| Docker or self-hosting | Throwaway containers, volumes and networks. Say plainly what a Mac can't show and let the Linux CI runner prove it |

Open every screenshot and confirm it shows what its caption claims. Never describe evidence that wasn't captured.

## Step 4: Review, push, describe

The lead reads the full diff against main, then pushes and approves the CI runs as `commit-pr` describes for fork PRs. Append this below the contributor's description, and read the body back to confirm every image is an uploaded URL:

```markdown
---

## Maintainer changes

### Reproduction
Before: `<command>` -> <failure excerpt>, or the before screenshot
After: `<same command>` -> <result>, or the after screenshot

### What changed on top of @<author>'s commits
- <what and why; no account of how the fix was reached>

### Test plan
- [x] <exact command and result>

### Deploy notes
<targets from the table in commit-pr section 4; migrations; Celery restart>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

When a later push changes the code, bring this section in line with the final state.

## Step 5: The comment to the contributor

Written as Sam. His own, on #2182: "Thanks for this, it was a real gap. I made a few changes on top before merging:" followed by a short list, then "Merged and deploying now."

- Before merging, say "I pushed a few changes on top:" and list them in plain words.
- No em dashes, no hyphens as punctuation, no polish, and no reason or claim Sam hasn't made himself.
- Don't open two comments to the same person with the same sentence.
- Answer anything they asked, such as what is left before merging.

Show Sam the full text in the question. Post it once, after Django Tests passes on the final head.

## Step 6: Before Sam merges

1. Merge every ready PR together onto current `origin/main` in a throwaway detached worktree and run the full `apps` suite once. Each PR was only ever tested alone. Remove the worktree afterwards.
2. Report one row per PR: the problem, what changed, and the deploy targets. Then list what wasn't verified, any flaky test seen, and anything left on the machine.
3. Merge and deploy only on Sam's word, following `commit-pr`.
4. Afterwards, delete the throwaway dev users and feeds, and close each worktree with `make worktree-close`. It refuses while untracked files exist, so remove `screenshots/` once the images are confirmed uploaded.

## Running several PRs with subagents

- **Memory.** The Docker VM has 8 GB and a worktree stack takes about 850 MB. Run at most two extra stacks, check `docker run --rm alpine free -m` before starting one, and stop a stack's celery, node and mcp containers when only tests are needed. Never stop a container another session started.
- **Tests.** Every checkout shares one test database, so two runs anywhere collide. Serialize them with a lock directory, and check `pg_stat_activity` for connections to the test database from another session before starting.
- **Limits on subagents.** They stop before pushing, never post comments, never approve CI runs, and bring back a question with options instead of guessing.
- **Their reports.** Check a report against GitHub (`gh pr view`, `git ls-remote`) before acting on it. Reports arrive cut off, and an idle notice can predate the last message sent to that agent.
- **`newsblur_web/settings.py`.** A privacy hook refuses any Bash command that names the file. Use Read and Edit on it.
- **Shared dev database.** Throwaway users and feeds are fine. Never change the `django_site` row or another user's preferences.
