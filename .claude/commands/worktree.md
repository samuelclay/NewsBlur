---
description: Create a git worktree and start development environment
---

## Your task

Create a new git worktree for the branch specified in the arguments and start the development environment.

**Arguments provided:** {{ arguments }}

### Steps to execute

1. **Parse the branch name** from the arguments (the first word)

2. **Create the worktree** using auto-detect logic (try new branch first, fall back to existing):
   ```bash
   BRANCH_NAME="<parsed-branch-name>"
   git worktree add ".worktree/${BRANCH_NAME}" -b "${BRANCH_NAME}" 2>/dev/null || \
   git worktree add ".worktree/${BRANCH_NAME}" "${BRANCH_NAME}"
   ```

3. **Change the working directory** to the new worktree:
   ```bash
   cd ".worktree/${BRANCH_NAME}"
   ```

4. **Run worktree-dev.sh** to start the development environment:
   ```bash
   ./worktree-dev.sh
   ```

5. **Report success** including:
   - The workspace URL (from worktree-dev.sh output)
   - That the working directory is now `.worktree/<branch-name>`
   - Available commands: `make worktree-log`, `make worktree-close`
