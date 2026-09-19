# Personalized Discovery

The web reader exposes a separate Discovery stream at `/folder/discovery`. It
uses the normal story reading behavior. Inline **More like this** and **Less
like this** buttons train future recommendations without opening the article,
changing its read state, subscribing to its feed, or creating intelligence
classifier rules. The buttons sit in the normal article header alongside its
date and author, with the actual source title and favicon above. A saved choice
expands to fill the button pair, with a brief star flourish that respects reduced
motion. Click the confirmation to edit, then the selected choice again to clear
it. Failed requests keep the confirmed preference and offer Retry.

Discovery's sidebar count area and stream header show green/red number badges
and a two-sided sparkline. At 0:0, a muted constellation replaces the counts.
The compact chart starts just before its first recent choice so a few votes
remain legible; the history dialog keeps the full 30-day window. Clicking either opens a
dialog with paginated lists of current choices, controls to switch or clear each
one, and a 30-day UTC timeline grouped by each choice's last update. Counts cover
all active choices, including older ones. Cleared choices disappear from the
lists, counts, and chart. Saved article snapshots remain editable after RSS
story expiry. Changes also update any currently displayed article controls.

## Archive access and the weekly preview

Premium Archive and Pro readers get the full stream. Other signed-in readers
get up to three stories per calendar week, resetting Monday at 00:00 UTC. The
selection is generated on the first open that week, then stored in MongoDB as
`MDiscoveryPreview`. Refreshes, reading, feedback, browser changes, and cache
eviction cannot replace those picks. Read stories remain available. Removed or
newly followed sources are omitted without replenishing the allowance. An empty
candidate pool does not consume a preview; concurrent first opens use the same
atomic selection. Weekly records expire two weeks after their reset date and
are removed when the account is deleted.

While the first response is pending, a small constellation animates above a
loading state. New picks enter in a short stagger without delaying the request
or changing read state. Returning to a saved preview skips the entrance motion.
All motion respects reduced-motion preferences. A callout beneath the preview
opens the upgrade dialog with personalized Discovery highlighted in Archive.

## Ranking and data

`discovery.py` implements a bounded text-similarity baseline, with no external
model calls. The earlier offline Jev experiment remains separate from this
reader implementation; see [Jev findings](JEV_FINDINGS.md) for measured costs,
ranking results, and limitations. This baseline is experimental, not a validated
measure of recommendation quality.

- Candidates come from up to 120 stories each in Good Reads, Long Reads, and
  Widely Read. Discovery excludes followed feeds and matching feed aliases,
  private branches, newsletters, forbidden feeds, and obvious credential-bearing
  feed URLs. Canonical article links deduplicate the candidate pool.
- The profile uses the latest 150 read hashes with at least 30 seconds of
  recorded reading time in the existing eight-day window, plus the latest 30
  saved and 30 shared stories. Reading time uses bounded Redis point lookups.
  Cached original text is preferred where available; no text fetch is launched.
- The latest 200 nonzero explicit votes contribute stronger positive or negative
  examples. A vote overrides a passive example for that story. Missing feedback
  and brief views are not treated as dislikes.
- The reading profile is cached for five minutes. A fresh full-stream load reads
  current votes and ranks candidates again. Pagination uses a user-owned,
  one-hour snapshot so feedback does not move stories during the current read.
  Access and subscriptions are rechecked on each page. A continuation cursor
  advances past newly ineligible stories without ending the stream early.
  These rechecks load only metadata in fixed batches of at least 12 candidates,
  without article text, and read subscription identities once per request. The
  cursor advances only through consumed candidates when a batch fills the page.
- Accounts without examples receive a deterministic ordering from the candidate
  lists, with source diversity. An empty candidate pool produces an empty state.

`MRecommendationFeedback` stores one current preference per user and story hash
in MongoDB, along with timestamps, surface, and durable article context. Repeated
votes replace that preference. Account deletion removes its feedback. No SQL
migration is introduced. Feedback is not an exposure log or an immutable event
history; those evaluation capabilities and a live Jev ranker are outside this
initial implementation. Automatic Focus skipping is also outside this change.

## API

- `GET /reader/trending_stories?trending_type=discovery` returns the existing
  reader story format, `recommendation_feedback` on each story, and a
  `discovery_snapshot` plus `discovery_next_cursor`. Subsequent pages pass that
  snapshot and the returned cursor as `discovery_cursor`. Discovery
  requires authentication and supplies the CSRF cookie used by feedback.
  Non-Archive readers also receive `discovery_preview` with `limited`, `limit`,
  `generated`, and `resets_at`; a null next cursor ends their weekly selection.
  Client-supplied limits, filters, and snapshots cannot bypass the weekly gate.
- `POST /recommendations/story_feedback` accepts `story_hash`, `value` (`-1`,
  `0`, or `1`), and `surface=discovery`. It requires authentication and a CSRF
  token, and returns the persisted value. The legacy `good_reads` surface is
  accepted by storage, but feedback controls appear only in Discovery.
- `GET /recommendations/feedback_history` returns the signed-in reader's active
  choices, source metadata, counts, and timeline. Use `value=1` or `value=-1`
  for either list and `next_cursor` as `cursor` for the next 20 results. Cursors
  are signed, expire after one hour, and are scoped to both account and choice.
  `summary=1` returns only counts and timeline for the stream header.

## Development

Worktree: `.worktree/jev-discover`, branch `jev-discover`. Start its services with
`make worktree`. The generated worktree configuration currently assigns Django
port `8439`; local preview is
`http://localhost:8439/reader/dev/autologin/samuel/?next=/folder/discovery`.
Development databases are shared across worktrees. Local preview stories are
synthetic examples, not a copy of the production account's recommendations.

The optional offline experiment helper reads its OpenRouter key from
`/srv/secrets-newsblur/keys/openrouter-jev.env` (mode `0600`). Private research
inputs, responses, and the existing $10 budget ledger live under
the gitignored `.jev-discover/` directory in this worktree (mode `0700`). The key
is also configured in the private secrets repo's `settings/common_settings.py`
for the staging secrets sync. The Discovery web path does not need that key.
Staging deployment evidence and the exact deployed commit are recorded in PR #2140.

Focused checks:

```sh
docker exec -t newsblur_web_jev-discover python manage.py test apps.recommendations --settings=newsblur_web.test_settings --noinput -v 1
node --test node/tests/recommendation_feedback.test.js node/tests/recommendation_history.test.js node/tests/discovery_pagination.test.js node/tests/story_selection_utils.test.js node/tests/story_pane_resize.test.js node/tests/story_title_narrow_layout.test.js
```
