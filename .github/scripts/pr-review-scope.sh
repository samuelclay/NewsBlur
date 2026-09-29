#!/usr/bin/env bash
# .github/scripts/codex-review-scope.sh
#
# Decides how much of a pull request the Codex PR review should read, so that a push
# to a long-running PR reviews only the new commits instead of the whole PR again.
# Called from .github/workflows/codex-pr-review.yml with the repository checked out
# at the PR merge commit (refs/pull/N/merge) as a blobless clone with full history.
#
# Modes written to $GITHUB_OUTPUT:
#   full         No earlier Codex review to build on, or one exists but cannot be
#                diffed against. Codex reviews `git diff HEAD^1 HEAD` as before.
#   incremental  A previous Codex review exists. Codex reviews only what the PR
#                changed since that review. The previously reviewed commit is merged
#                into the current base with `git merge-tree`, and that tree is diffed
#                against the current merge commit, so commits merged in from main
#                between the two reviews do not show up as changes to review.
#   skip         Nothing changed since the previous review (same head, or only a
#                merge from main or a rebase). The workflow does not run Codex.
#
# Environment (set by the workflow):
#   GITHUB_REPOSITORY, PR_NUMBER, PR_HEAD_SHA, PR_LABELS_JSON, RUNNER_TEMP,
#   GITHUB_OUTPUT, GH_TOKEN (read access to pull requests, used to list reviews).
set -euo pipefail

: "${GITHUB_REPOSITORY:?}" "${PR_NUMBER:?}" "${PR_HEAD_SHA:?}" "${RUNNER_TEMP:?}" "${GITHUB_OUTPUT:?}"
PR_LABELS_JSON="${PR_LABELS_JSON:-[]}"

full_diff_file="$RUNNER_TEMP/codex-full-pr.diff"
incremental_diff_file="$RUNNER_TEMP/codex-incremental.diff"
head_short="${PR_HEAD_SHA:0:7}"

# Codex runs in a read-only sandbox without network access, and this checkout is a
# blobless clone, so every blob a diff needs has to be fetched here while the job
# still has network. Producing the full PR diff once pulls in the base-side blobs of
# every changed file. codex-review-scope.sh keeps the file so Codex can read it too.
git diff HEAD^1 HEAD > "$full_diff_file"
full_diff_lines=$(wc -l < "$full_diff_file" | tr -d ' ')

# The most recent Codex review on this PR names the head it reviewed. Reviews posted
# by codex-pr-review.yml carry `<!-- codex-pr-review head=<sha> -->`; reviews from
# before that marker existed fall back to the review's commit_id, which GitHub set to
# the PR head at posting time. The API call is best effort: on any failure the PR
# gets a full review rather than a failed job.
previous_head=""
if reviews_json=$(gh api "repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews" --paginate --slurp 2>/dev/null); then
  previous_head=$(jq -r '
    add
    | map(select(.user.login == "github-actions[bot]" and ((.body // "") | contains("<!-- codex-pr-review"))))
    | map({
        at: .submitted_at,
        sha: ((.body | capture("<!-- codex-pr-review head=(?<sha>[0-9a-f]{40}) -->") | .sha) // .commit_id)
      })
    | sort_by(.at) | last | .sha // empty
  ' <<<"$reviews_json")
fi
previous_short="${previous_head:0:7}"

mode="full"
reason=""
previous_tree=""
if jq -e 'index("codex-full-review") != null' <<<"$PR_LABELS_JSON" >/dev/null; then
  reason="the codex-full-review label asks for a full review"
elif [ -z "$previous_head" ]; then
  reason="first Codex review of this PR"
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
    scope_line="Reviewed only the $new_commit_count commit(s) pushed since the last Codex review ($previous_short..$head_short); earlier changes were not re-reviewed."
    instructions=$(cat <<EOF
- Codex already reviewed this PR at commit $previous_short. Since then the author pushed $new_commit_count commit(s):
$new_commits
- Review only what changed since that review. The incremental diff is saved at $incremental_diff_file and is the same as \`git diff $previous_tree HEAD\`. It excludes anything merged in from the base branch.
- The full PR diff, \`git diff HEAD^1 HEAD\` (saved at $full_diff_file), is for context only. Do not re-report findings about code that did not change since the previous review, and anchor inline comments only to lines that appear in the incremental diff.
EOF
)
    echo "Incremental diff: $incremental_diff_lines lines (full PR diff: $full_diff_lines lines)"
    ;;
  skip)
    scope_line="Skipped the Codex review: $reason."
    ;;
esac

{
  echo "mode=$mode"
  echo "scope_line=$scope_line"
  echo "instructions<<CODEX_SCOPE_EOF"
  echo "$instructions"
  echo "CODEX_SCOPE_EOF"
} >> "$GITHUB_OUTPUT"
echo "::notice title=Codex review scope::$scope_line"
