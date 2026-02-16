---
description: Group all changes semantically and commit each group separately
allowed-tools: Bash
---

## Context

- Current git status: !`git status`
- Current branch: !`git branch --show-current`
- Staged changes: !`git diff --staged --stat`
- Unstaged changes: !`git diff --stat`
- Full diff of all changes: !`git diff HEAD`
- Recent commits (for message style): !`git log --oneline -10`

## Your task

Analyze ALL uncommitted changes (staged and unstaged) and group them into logical, semantically related commits. Then create one commit per group.

### Step 1: Analyze and group changes

Review every changed file in the diff above. Group them by logical purpose:

- Files that are part of the same feature or fix belong together
- Config changes related to a feature go with that feature
- Unrelated fixes, style changes, or independent modifications get their own commits
- Test files go with the code they test

Present the proposed grouping to the user before proceeding. List each group with:
- A proposed commit message
- The files in that group

Ask the user to confirm or adjust the grouping.

### Step 2: Commit each group

For each group (in logical order — foundational changes first):

1. Reset the staging area: `git reset HEAD` (if anything is staged)
2. Stage only the files for this group: `git add <specific-files>`
3. Verify with `git diff --staged --stat`
4. Commit with a HEREDOC message following the project conventions:
   - Imperative mood, present tense
   - Concise summary under 80 characters
   - End with `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

### Step 3: Confirm

Run `git log --oneline -<N>` (where N = number of commits created) and `git status` to show:
- All commits created (hash + message)
- Any remaining uncommitted files and why they were excluded

Do not push. Do not create a PR.
