---
description: Commit, push, and create or update a pull request
---

## Your task

Commit all staged/unstaged changes, push to remote, and either update an existing PR or create a new one.

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
   - If a PR exists and is OPEN, note its URL - we'll update it
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
   - Report: "Updated existing PR: <url>"

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

7. **Report the result**:
   - Show the PR URL
   - Indicate whether it was created or updated
   - Show the commit hash and message
