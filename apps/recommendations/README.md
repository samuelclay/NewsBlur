# Personalized Discovery

The web reader exposes a separate Discovery stream at `/folder/discovery`. It
uses the normal story reading behavior. Inline **More like this** and **Less
like this** buttons train future recommendations without opening the article,
changing its read state, subscribing to its feed, or creating intelligence
classifier rules. A selected button clears its vote when clicked again. Undo
restores the preceding preference; failed requests keep the confirmed state and
offer Retry.

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
- The reading profile is cached for five minutes. A fresh stream load reads
  current votes and ranks candidates again. Pagination uses a user-owned,
  one-hour snapshot so feedback does not move stories during the current read.
  Access and subscriptions are rechecked on each page. A continuation cursor
  advances past newly ineligible stories without ending the stream early.
  These rechecks load only metadata in page-sized batches, without article text.
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
- `POST /recommendations/story_feedback` accepts `story_hash`, `value` (`-1`,
  `0`, or `1`), and `surface=discovery`. It requires authentication and a CSRF
  token, and returns the persisted value. The legacy `good_reads` surface is
  accepted by storage, but feedback controls appear only in Discovery.

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
`/srv/secrets-newsblur/jev-discover/` (directory mode `0700`). They are outside
Git. The Discovery web path does not need that key. No staging or production
deployment has been performed for this change.

Focused checks:

```sh
docker exec -t newsblur_web_jev-discover python manage.py test apps.recommendations --settings=newsblur_web.test_settings --noinput -v 1
node --test node/tests/recommendation_feedback.test.js node/tests/discovery_pagination.test.js node/tests/story_selection_utils.test.js node/tests/story_pane_resize.test.js node/tests/story_title_narrow_layout.test.js
```
