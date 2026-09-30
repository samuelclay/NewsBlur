#!/usr/bin/env bash
# .github/scripts/pr-review-scope.sh
#
# Decides how much of a pull request an automated PR review bot should read, so that a
# push to a long-running PR reviews only the new commits instead of the whole PR again.
# Called from .github/workflows/codex-pr-review.yml (REVIEWER=codex) and
# .github/workflows/claude-pr-review.yml (REVIEWER=claude) with the repository checked
# out at the PR merge commit (refs/pull/N/merge) as a blobless clone with full history.
#
# Modes written to $GITHUB_OUTPUT:
#   full         No earlier review by this bot to build on, or one exists but cannot be
#                diffed against. The bot reviews `git diff HEAD^1 HEAD` as before.
#   incremental  A previous review exists. The bot reviews only what the PR changed
#                since that review. The previously reviewed commit is merged into the
#                current base with `git merge-tree`, and that tree is diffed against the
#                current merge commit, so commits merged in from main between the two
#                reviews do not show up as changes to review.
#   skip         Nothing changed since the previous review (same head, or only a
#                merge from main or a rebase). The workflow does not run the bot.
#
# How the previously reviewed head is found:
#   codex   Reviews posted by codex-pr-review.yml carry
#           `<!-- codex-pr-review head=<sha> -->`; older reviews fall back to the
#           review's commit_id.
#   claude  Claude posts its own comments, so there is no marker to trust. The head
#           of the most recent successful claude-pr-review.yml run for this PR is the
#           last head Claude finished reviewing. Cancelled runs (superseded by a newer
#           push) and failed runs do not count, so their commits get reviewed next time.
#
# A `<reviewer>-full-review` label on the PR (codex-full-review, claude-full-review)
# forces a full review.
#
# Environment (set by the workflow):
#   REVIEWER (codex or claude), GITHUB_REPOSITORY, PR_NUMBER, PR_HEAD_SHA, PR_HEAD_REF,
#   PR_LABELS_JSON, RUNNER_TEMP, GITHUB_OUTPUT, GH_TOKEN (read access to pull requests
#   for codex, to actions for claude).
set -euo pipefail

: "${REVIEWER:?}" "${GITHUB_REPOSITORY:?}" "${PR_NUMBER:?}" "${PR_HEAD_SHA:?}" "${RUNNER_TEMP:?}" "${GITHUB_OUTPUT:?}"
PR_LABELS_JSON="${PR_LABELS_JSON:-[]}"
PR_HEAD_REF="${PR_HEAD_REF:-}"

case "$REVIEWER" in
  codex) reviewer_name="Codex" ;;
  claude) reviewer_name="Claude" ;;
  *)
    echo "::error::pr-review-scope.sh: unknown REVIEWER '$REVIEWER' (expected codex or claude)"
    exit 1
    ;;
esac
full_review_label="$REVIEWER-full-review"

full_diff_file="$RUNNER_TEMP/$REVIEWER-full-pr.diff"
incremental_diff_file="$RUNNER_TEMP/$REVIEWER-incremental.diff"
head_short="${PR_HEAD_SHA:0:7}"

# Codex runs in a read-only sandbox without network access, and this checkout is a
# blobless clone, so every blob a diff needs has to be fetched here while the job
# still has network. Producing the full PR diff once pulls in the base-side blobs of
# every changed file. pr-review-scope.sh keeps the file so the bot can read it too.
git diff HEAD^1 HEAD > "$full_diff_file"
full_diff_lines=$(wc -l < "$full_diff_file" | tr -d ' ')

# Prints the head the bot last reviewed on this PR, or nothing. The API calls are best
# effort: on any failure the PR gets a full review rather than a failed job.
find_previous_head() {
  case "$REVIEWER" in
    codex)
      local reviews_json
      if reviews_json=$(gh api "repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews" --paginate --slurp 2>/dev/null); then
        jq -r '
          add
          | map(select(.user.login == "github-actions[bot]" and ((.body // "") | contains("<!-- codex-pr-review"))))
          | map({
              at: .submitted_at,
              sha: ((.body | capture("<!-- codex-pr-review head=(?<sha>[0-9a-f]{40}) -->") | .sha) // .commit_id)
            })
          | sort_by(.at) | last | .sha // empty
        ' <<<"$reviews_json"
      fi
      ;;
    claude)
      # Runs come back newest first. The branch filter keeps the list short; the
      # pull_requests check keeps a same-named branch on another PR from matching.
      if [ -n "$PR_HEAD_REF" ]; then
        gh api -X GET "repos/$GITHUB_REPOSITORY/actions/workflows/claude-pr-review.yml/runs" \
          -f event=pull_request -f status=success -f branch="$PR_HEAD_REF" -F per_page=50 \
          --jq "[.workflow_runs[] | select(any(.pull_requests[]; .number == $PR_NUMBER))] | first | .head_sha // empty" \
          2>/dev/null || true
      fi
      ;;
  esac
}

previous_head=$(find_previous_head)
previous_short="${previous_head:0:7}"

mode="full"
reason=""
previous_tree=""
if jq -e --arg label "$full_review_label" 'index($label) != null' <<<"$PR_LABELS_JSON" >/dev/null; then
  reason="the $full_review_label label asks for a full review"
elif [ -z "$previous_head" ]; then
  reason="first $reviewer_name review of this PR"
elif [ "$previous_head" = "$PR_HEAD_SHA" ]; then
  mode="skip"
  reason="commit $head_short was already reviewed"
elif ! git fetch --quiet --no-tags --filter=blob:none origin "$previous_head"; then
  reason="the previously reviewed commit $previous_short can no longer be fetched"
else
  # Recreate what the previous review saw: the previously reviewed commit merged into
  # the base as it stands now. Diffing that tree against the current merge commit
  # yields only the PR's own changes since the last review. A conflicting merge makes
  # `git merge-tree --write-tree` exit non-zero, which falls back to a full review.
  base_tip=$(git rev-parse HEAD^1)
  if previous_tree=$(git merge-tree --write-tree "$base_tip" "$previous_head" 2>/dev/null); then
    git diff "$previous_tree" HEAD > "$incremental_diff_file"
    if [ -s "$incremental_diff_file" ]; then
      mode="incremental"
    else
      mode="skip"
      reason="nothing changed since the review of $previous_short (only a merge from the base branch or a rebase)"
    fi
  else
    reason="merging the previously reviewed commit $previous_short into the base branch conflicts"
  fi
fi

instructions=""
scope_line=""
case "$mode" in
  full)
    scope_line="Reviewed the full PR diff ($reason)."
    instructions="- Review the PR diff with \`git diff HEAD^1 HEAD\`. The same diff is saved at $full_diff_file."
    ;;
  incremental)
    new_commit_count=$(git rev-list --count --no-merges "$previous_head..$PR_HEAD_SHA")
    new_commits=$(git log --no-merges --format='  - %h %s' "$previous_head..$PR_HEAD_SHA" | head -40)
    incremental_diff_lines=$(wc -l < "$incremental_diff_file" | tr -d ' ')
    scope_line="Reviewed only the $new_commit_count commit(s) pushed since the last $reviewer_name review ($previous_short..$head_short); earlier changes were not re-reviewed."
    instructions=$(cat <<EOF
- $reviewer_name already reviewed this PR at commit $previous_short. Since then the author pushed $new_commit_count commit(s):
$new_commits
- Review only what changed since that review. The incremental diff is saved at $incremental_diff_file and is the same as \`git diff $previous_tree HEAD\`. It excludes anything merged in from the base branch.
- The full PR diff, \`git diff HEAD^1 HEAD\` (saved at $full_diff_file), is for context only. Do not re-report findings about code that did not change since the previous review, and anchor inline comments only to lines that appear in the incremental diff.
EOF
)
    echo "Incremental diff: $incremental_diff_lines lines (full PR diff: $full_diff_lines lines)"
    ;;
  skip)
    scope_line="Skipped the $reviewer_name review: $reason."
    ;;
esac

{
  echo "mode=$mode"
  echo "scope_line=$scope_line"
  echo "instructions<<PR_REVIEW_SCOPE_EOF"
  echo "$instructions"
  echo "PR_REVIEW_SCOPE_EOF"
} >> "$GITHUB_OUTPUT"
echo "::notice title=$reviewer_name review scope::$scope_line"
