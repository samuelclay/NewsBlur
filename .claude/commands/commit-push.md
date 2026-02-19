---
description: Smart commit and push to remote
allowed-tools: Bash, Skill(commit)
---

## Your task

First, invoke the `/commit` skill to create a scoped commit. Then push to remote.

### Step 1: Commit

Invoke the `/commit` command to stage and commit the conversation-relevant changes.

### Step 2: Push

After the commit succeeds, push the current branch to origin:

```
git push -u origin HEAD
```

If the push fails due to diverged history, report the error and ask the user how to proceed. Do NOT force push.

### Step 3: Confirm

Run `git status` and report:
- The commit hash and message (from the commit step)
- The remote branch that was pushed to
- Whether the push succeeded
