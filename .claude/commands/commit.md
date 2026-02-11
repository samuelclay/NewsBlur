---
description: Smart commit that stages only conversation-relevant changes
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

Create a single git commit with only the changes relevant to this conversation session.

### Step 1: Determine which files to stage

Analyze the conversation history and the diff above to identify which files were actively worked on during this session. Consider:

- Files you created, edited, or wrote during this conversation
- Files that are logically related to the work discussed
- Do NOT stage files with unrelated changes (pre-existing dirty state, editor configs, etc.)

If ALL changed files are clearly part of the current work, stage them all. If unsure about a file, leave it unstaged.

### Step 2: Stage the relevant files

Use `git add` with specific file paths. Do NOT use `git add -A` or `git add .`.

If there are already-staged files that are NOT part of this session's work, unstage them with `git reset HEAD <file>`.

### Step 3: Verify staged changes

Run `git diff --staged --stat` to confirm only the intended files are staged.

### Step 4: Commit

Follow the commit message conventions from the recent commits above:
- Imperative mood, present tense ("Add...", "Fix...", "Rename...", "Enable...")
- Concise summary under 80 characters
- If non-trivial, add a blank line and brief body explaining the "why"
- End with `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

Use a HEREDOC:
```
git commit -m "$(cat <<'EOF'
<summary line>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

### Step 5: Confirm

Run `git status` and report:
- The commit hash and message
- Which files were committed
- Which files remain unstaged (if any) and why they were excluded

Do not push. Do not create a PR.
