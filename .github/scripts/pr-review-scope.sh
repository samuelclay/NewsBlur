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
#   full         First review or explicit full-review label. Claude also falls back to
#                full when its previously reviewed head cannot be compared.
#   incremental  A previous review exists. The bot reviews only what the PR changed
#                since that review. The previously reviewed commit is merged into the
#                current base with `git merge-tree`, and that tree is diffed against the
#                current merge commit, so commits merged in from main between the two
#                reviews do not show up as changes to review.
#   skip         Nothing changed since the previous review (same head, or only a
#                merge from main or a rebase). The workflow does not run the bot.
#
# How the previously reviewed head is found:
#   codex   The first review posted by codex-pr-review.yml carries
#           `<!-- codex-pr-review head=<sha> -->`, and each later review rewrites that
#           marker to its own head instead of posting a new summary. Reviews from
#           before the marker existed fall back to the review's commit_id.
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

diff_file="$RUNNER_TEMP/$REVIEWER-review.diff"
head_short="${PR_HEAD_SHA:0:7}"

# Print the head the bot last reviewed on this PR, or nothing for a first review.
find_previous_head() {
  case "$REVIEWER" in
    codex)
      # An API error must not turn a follow-up into a paid full review.
      gh api "repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews" --paginate --slurp |
        jq -r '
          add
          | map(select(.user.login == "github-actions[bot]" and ((.body // "") | contains("<!-- codex-pr-review"))))
          | map({
              at: .submitted_at,
              sha: ((.body | capture("<!-- codex-pr-review head=(?<sha>[0-9a-f]{40}) -->") | .sha) // .commit_id)
            })
          | sort_by(.at) | last | .sha // empty
        '
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

full_requested=$(jq -r --arg label "$full_review_label" 'index($label) != null' <<<"$PR_LABELS_JSON")
if ! previous_head=$(find_previous_head); then
  if [ "$full_requested" != "true" ]; then
    echo "::error::Could not read the previous $reviewer_name review. Retry the workflow."
    exit 1
  fi
  previous_head=""
fi
previous_short="${previous_head:0:7}"

mode="full"
reason=""
diff_base="HEAD^1"
if [ "$full_requested" = "true" ]; then
  reason="the $full_review_label label asks for a full review"
elif [ -z "$previous_head" ]; then
  reason="first $reviewer_name review of this PR"
elif [ "$previous_head" = "$PR_HEAD_SHA" ]; then
  mode="skip"
  reason="commit $head_short was already reviewed"
else
  reason="could not compare the previously reviewed commit $previous_short against the current base"
  if git fetch --quiet --no-tags --filter=blob:none origin "$previous_head"; then
    merge_status=0
    merge_result=$(git merge-tree --write-tree HEAD^1 "$previous_head") || merge_status=$?
    # On a conflict (exit 1), merge-tree still writes the auto-merged tree on its
    # first line. Comparing that tree with HEAD includes the author's conflict
    # resolutions and excludes unrelated changes from main.
    if [ "$merge_status" -eq 0 ] || { [ "$merge_status" -eq 1 ] && [ "$REVIEWER" = "codex" ]; }; then
      diff_base=${merge_result%%$'\n'*}
      mode="incremental"
    fi
  fi
  if [ "$mode" = "full" ] && [ "$REVIEWER" = "codex" ]; then
    echo "::error::$reason. Retry, or add $full_review_label and push or reopen for a full review."
    exit 1
  fi
fi

if [ "$mode" != "skip" ]; then
  # Materialize only the selected patch while pr-review-scope.sh has network access.
  git diff "$diff_base" HEAD > "$diff_file"
  if [ ! -s "$diff_file" ]; then
    mode="skip"
    reason="the selected diff is empty"
  fi
fi

instructions=""
scope_line=""
case "$mode" in
  full)
    scope_line="Reviewed the full PR diff ($reason)."
    instructions="- Review the PR diff at $diff_file (\`git diff $diff_base HEAD\`)."
    ;;
  incremental)
    scope_line="Reviewed only the changes since the last $reviewer_name review ($previous_short..$head_short)."
    instructions="- Read the incremental patch at $diff_file (\`git diff $diff_base HEAD\`). Report only issues introduced by that patch. Consult surrounding code only as needed to understand those changes."
    ;;
  skip)
    scope_line="Skipped the $reviewer_name review: $reason."
    ;;
esac

# codex-pr-review.yml posts the summary only on a PR's first Codex review, so a later
# review has to carry every finding as an inline comment or it is never seen.
if [ "$REVIEWER" = "codex" ] && [ -n "$previous_head" ] && [ "$mode" != "skip" ]; then
  instructions="$instructions
- This PR already has a Codex summary review, so the \`summary\` from this run is not posted. Leave \`summary\` empty and put every finding in \`inline_comments\`."
fi

{
  echo "mode=$mode"
  echo "scope_line=$scope_line"
  echo "instructions<<PR_REVIEW_SCOPE_EOF"
  echo "$instructions"
  echo "PR_REVIEW_SCOPE_EOF"
} >> "$GITHUB_OUTPUT"
echo "::notice title=$reviewer_name review scope::$scope_line"
