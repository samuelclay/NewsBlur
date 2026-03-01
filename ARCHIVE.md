# NewsBlur Archive Subsystem

NewsBlur's "archive" work spans two related but distinct areas:

1. The browser-extension archive, which captures pages you browse and stores them in MongoDB for browsing, search, and AI-assisted recall.
2. The Premium Archive subscription tier, which also unlocks larger feed limits and full RSS-history backfills for subscribed feeds.

This document focuses on the browser-extension archive and Archive Assistant implementation, while calling out the subscription-tier behaviors that affect local development.

## What Lives Where

| Area | Main files | Responsibility |
|------|------------|----------------|
| Browser extension | `clients/browser-extension/src/background/service-worker.js`, `clients/browser-extension/src/lib/api.js`, `clients/browser-extension/src/popup/popup.js` | Capture browsing activity, queue pending archives, authenticate with OAuth, and sync archives to Django |
| Archive backend | `apps/archive_extension/views.py`, `apps/archive_extension/models.py`, `apps/archive_extension/matching.py`, `apps/archive_extension/tasks.py`, `apps/archive_extension/search.py` | Ingest pages, deduplicate, match them to NewsBlur stories, store archive documents, index for search, and manage categories/blocklists |
| Archive Assistant | `apps/archive_assistant/views.py`, `apps/archive_assistant/tasks.py`, `apps/archive_assistant/tools.py`, `apps/archive_assistant/models.py` | Queue AI queries, stream responses, persist conversations, and expose archive-aware tools |
| Web UI | `media/js/newsblur/views/archive_view.js`, `media/js/newsblur/reader/reader.js`, `templates/reader/feeds_skeleton.xhtml` | Premium Archive-only `/archive` view, browser/search UI, settings UI, and assistant chat |
| Realtime bridge | `node/unread_counts.js`, `node/archive_assistant.js` | Relay Redis PubSub messages to Socket.IO events consumed by the web UI |

## End-to-End Flow

```text
Browser extension
  -> queue page visit in extension storage
  -> POST /api/archive/ingest or /api/archive/batch_ingest
  -> match_and_process()
  -> MArchivedStory in analytics MongoDB
  -> archive-index-elasticsearch + archive-categorize Celery tasks
  -> Redis PubSub "archive:*"
  -> node/unread_counts.js
  -> archive:new / archive:deleted / archive:categories Socket.IO events
  -> media/js/newsblur/views/archive_view.js

Archive Assistant
  -> POST /archive-assistant/query
  -> process_archive_query task on push_feeds
  -> Claude tool calls against archives + starred/feed/shared stories
  -> Redis PubSub "archive_assistant:*"
  -> node/archive_assistant.js
  -> archive_assistant:* Socket.IO events
  -> archive_view.js streaming chat UI
```

## Browser Extension Ingestion

### Capture and batching

- The service worker starts tracking a tab when a page finishes loading.
- Pages are ignored for incognito tabs, browser/internal schemes, and blocklisted URLs.
- `TIME_THRESHOLDS.MIN_TIME_ON_PAGE` is `5000` ms, so the first archive is created after 5 seconds on a page.
- The extension keeps a local pending queue in extension storage.
- Sync is debounced by `TIME_THRESHOLDS.SYNC_DEBOUNCE` (`5000` ms).
- Background sync sends up to `BATCH_CONFIG.MAX_BATCH_SIZE` (`10`) archives per request.
- `batch_ingest` enforces a backend hard cap of 100 archives per request.

### OAuth and authentication

- The extension uses OAuth client ID `newsblur-archive-extension` and requests scope `archive`.
- Redirect URIs are provisioned by `apps/archive_extension/migrations/0001_setup_archive_oauth.py`.
- `apps/archive_extension/management/commands/setup_archive_oauth.py` can update that OAuth application later.
- `NEWSBLUR_URL` matters because the migration includes `<NEWSBLUR_URL>/oauth/extension-callback/` in the redirect URI list.
- Archive views themselves are decorated with `ajax_login_required`, so the actual enforcement is "authenticated `request.user`", with OAuth bearer tokens resolved through NewsBlur's normal auth backends.

### Localhost special cases

- `clients/browser-extension/src/lib/api.js` rewrites `https://localhost` service-worker requests to direct HTTP ports because browser extension service workers do not tolerate the local self-signed HTTPS setup.
- `clients/browser-extension/src/popup/popup.js` also contains a localhost-only direct sync path to `/api/archive/batch_ingest` while the popup is open.
- In worktrees, use the worktree URL shown by `./worktree-dev.sh`, then set that URL in the extension options as the custom server.

## Archive Backend

### Core document model

`MArchivedStory` in `apps/archive_extension/models.py` is stored in the analytics Mongo database (`MONGO_ANALYTICS_DB`, database name `nbanalytics`) in collection `archived_stories`.

Important fields:

- Ownership: `user_id`
- Identity and dedup: `url`, `url_hash`
- Display metadata: `title`, `favicon_url`, `domain`, `author`
- Content storage: `content_z` and `content_length`
- Visit tracking: `archived_date`, `first_visited`, `last_visited`, `visit_count`, `time_on_page_seconds`
- NewsBlur linkage: `matched_story_hash`, `matched_feed_id`, `content_source`
- AI classification: `ai_categories`, `ai_categorized_date`
- Extension metadata: `extension_version`, `browser`
- Lifecycle: `deleted`, `deleted_date`

Deduplication is per-user on `(user_id, url_hash)`. `archive_page()` updates an existing archive instead of creating a second copy when the normalized URL matches.

### URL normalization and story matching

`apps/archive_extension/matching.py` handles matching and processing:

- Tracking params such as `utm_*`, `fbclid`, `gclid`, `mc_cid`, and others are stripped during normalization.
- Existing NewsBlur stories are matched against `MStory.story_permalink` first, then `MStory.story_guid`.
- Matching is limited to the user's active subscriptions.
- When a match is found, `mark_story_read()` marks the story read through `UserSubscription.mark_story_ids_as_read()`.
- `content_source` is:
  - `extension` for archive-only pages
  - `newsblur` when the RSS story already has better content
  - `hybrid` when the page matches a NewsBlur story but the extension captured better text
- Extension content is only stored when it is meaningfully longer than the existing story content (`>10%` longer).

### API surface

Archive endpoints live under `/api/archive/`:

| Endpoint | Method | Notes |
|----------|--------|-------|
| `/ingest` | `POST` | Single archive ingest |
| `/batch_ingest` | `POST` | Batch ingest, max 100 archives |
| `/list` | `GET` | Browse archives, search, filters, pagination |
| `/categories` | `GET` | Category/domain/date breakdowns for the sidebar filters |
| `/domains` | `GET` | Top domains |
| `/stats` | `GET` | Aggregate archive stats |
| `/delete` | `POST` | Soft-delete explicit archive IDs |
| `/delete_by_domain` | `POST` | Soft-delete all non-deleted archives for one domain |
| `/blocklist` | `GET` | Read blocklist settings |
| `/blocklist/update` | `POST` | Update custom blocked domains, regex patterns, and allowlist |
| `/export` | `GET` | JSON or CSV export, optional `include_content=true` |
| `/categories/merge` | `POST` | Merge categories and reindex affected docs |
| `/categories/rename` | `POST` | Rename a category and reindex affected docs |
| `/categories/split` | `POST` | Ask Claude for split suggestions or apply a split |
| `/categories/suggest-merges` | `GET` | Similar-name suggestions |
| `/categories/bulk-categorize` | `POST` | Queue batch categorization of uncategorized archives |
| `/recategorize` | `POST` | Clear categories for specific archives and requeue categorization |

### Listing and search behavior

- `/api/archive/list` defaults to `limit=50` and caps at `200`.
- Without `search`, list browsing is served directly from MongoDB.
- With `search`, the view uses `SearchArchive.query_with_highlights()` and returns Elasticsearch highlights.
- Browser-tab search does not have a Mongo fallback if Elasticsearch is unavailable.
- Filters support `domain`, `category`, `date_from`, `date_to`, and `include_deleted=true`.

### Blocklist behavior

`MArchiveUserSettings` stores per-user archive settings in `archive_user_settings`.

Implemented fields:

- `blocked_domains`
- `blocked_patterns`
- `allowed_domains`
- `auto_archive_enabled`
- `archive_read_stories`
- `total_archived`
- `last_archive_date`

`apps/archive_extension/blocklist.py` ships a default privacy blocklist covering:

- Banking and finance
- Medical/health portals
- Webmail
- Password managers
- Direct messaging surfaces
- HR/payroll systems
- Government/tax portals
- Internal hostnames, private IP ranges, and auth/checkout/admin paths

Allowlisted domains override the default blocklist.

## Search and Indexing

Archive full-text search uses the `SearchArchive` helper in `apps/archive_extension/search.py`.

- Index name: `archives-index`
- Indexed fields: `title`, `content`, `url`, `domain`, `categories`, `user_id`, `archived_date`
- Search sorts by `archived_date`
- Query parsing preserves phrase quotes and sanitizes unbalanced quotes
- `query_with_highlights()` returns `<mark>`-wrapped snippets for the browser UI
- `reindex_user_archives(user_id)` exists for manual rebuilds

Indexing entry points:

- `index_archive_for_search.delay()` is queued for every ingest
- category-changing endpoints call `_reindex_categories_async()`
- `bulk_categorize_archives()` also reindexes after categorization

If Elasticsearch is down:

- Ingest still succeeds
- Index tasks log and return
- browser-tab archive search returns no results
- Archive Assistant search tools may fall back to a Mongo title query when their Elasticsearch lookup comes back empty

## AI Categorization

Categorization lives in `apps/archive_extension/tasks.py`.

- Task names: `archive-categorize`, `archive-bulk-categorize`
- Queue: `push_feeds`
- Only archives with stored content (`content_z`) are categorized
- The task prefers the user's existing categories before inventing new ones
- Claude model: `claude-haiku-4-5`
- Content is truncated to 4000 chars before prompting
- Max returned categories: 3
- Fallback categorization is domain-based (`News`, `Shopping`, `Technology`, `Social`, `Entertainment`, `Finance`)

Realtime category updates are published to Redis with `archive:` payloads of type `categories`, then pushed to the browser over Socket.IO as `archive:categories`.

## Archive Assistant

Assistant endpoints live under `/archive-assistant/`:

| Endpoint | Method | Notes |
|----------|--------|-------|
| `/query` | `POST` | Queue a new assistant query |
| `/conversations` | `GET` | List conversations |
| `/conversation/<id>` | `GET` | Fetch one conversation and its queries |
| `/conversation/<id>/delete` | `POST` | Soft-delete a conversation by setting `is_active=False` |
| `/suggestions` | `GET` | Suggested prompts based on archive categories/domains |
| `/usage` | `GET` | Daily usage counts and entitlement flags |

### Stored models

Archive Assistant data also lives in MongoDB:

- `MArchiveConversation` in collection `archive_conversations`
- `MArchiveQuery` in collection `archive_queries`
- `MArchiveAssistantUsage` in collection `archive_assistant_usage`

Responses are compressed in `response_z`, and each query records:

- `model`
- `duration_ms`
- `tokens_used`
- `referenced_archive_ids`
- `tool_calls`
- `error`

### Query execution

`submit_query()` creates the conversation/query records, then queues `process_archive_query` on `push_feeds`.

Key implementation details:

- Default model: `claude-sonnet-4-5`
- Max query length: `4096` characters
- Conversation context includes up to 10 previous query/response pairs
- Claude runs with `max_tokens=4096`
- Tool execution is parallelized with `ThreadPoolExecutor(max_workers=6)`
- Tooling spans three data sources:
  - browsing archive
  - starred/feed stories
  - shared/social stories

### Subscription behavior

Archive Assistant usage is intentionally looser than the `/archive` UI gate:

- `Profile.is_archive` users get `100` queries/day and full responses
- non-archive users get `20` queries/day
- non-archive responses are truncated after `300` characters (`FREE_RESPONSE_CHAR_LIMIT`)

The `/archive` web UI itself is gated client-side by `NEWSBLUR.Globals.is_archive` in `media/js/newsblur/reader/reader.js`, so direct API access and UI access are not the same thing.

## Redis PubSub and Socket.IO

Two archive-related message families are published on the user's Redis PubSub channel (`user.username`):

- `archive:{...}` for archive ingest/delete/category events
- `archive_assistant:{...}` for assistant streaming events

Publishers:

- `apps/archive_extension/views.py` publishes `new` and `deleted`
- `apps/archive_extension/tasks.py` publishes `categories`
- `apps/archive_assistant/tasks.py` publishes `start`, `chunk`, `tool_call`, `tool_result`, `complete`, `error`, and `truncated`

Consumers:

- `node/unread_counts.js` translates `archive:` messages into `archive:new`, `archive:deleted`, and `archive:categories`
- `node/archive_assistant.js` translates `archive_assistant:` messages into `archive_assistant:*`
- `media/js/newsblur/reader/reader.js` binds those Socket.IO events and forwards them to the active `ArchiveView`

## Web UI Consumption

The archive UI is anchored by `media/js/newsblur/views/archive_view.js`.

Main responsibilities:

- Assistant tab
  - loads suggestions and usage via `/archive-assistant/suggestions` and `/archive-assistant/usage`
  - submits questions to `/archive-assistant/query`
  - handles streaming Socket.IO events, including tool-call previews and truncation notices
- Browser tab
  - loads archives from `/api/archive/list`
  - loads filter metadata from `/api/archive/categories`
  - supports category/domain/date filters, search, pagination, and recategorization
- Settings tab
  - reads `/api/archive/blocklist`
  - updates blocklists
  - offers domain-based blocking and optional delete-by-domain workflows

The route itself is `/archive`, and the fake "Archive" sidebar folder is declared in `templates/reader/feeds_skeleton.xhtml`.

## Premium Archive Tier and Feed Backfill

The subscription tier affects more than the browser-extension archive.

When `Profile.activate_archive()` runs:

- `Profile.is_archive` is set
- `UserSubscription.schedule_fetch_archive_feeds_for_user()` is called
- archive feed fetch progress is published as `fetch_archive:start`, `fetch_archive:feeds:<ids>`, and `fetch_archive:done`
- `SchedulePremiumSetup` is queued with `allow_skip_resync=True`
- the user's full feed archive is backfilled on the search indexer queue

This feed-history backfill is separate from `MArchivedStory`, but contributors often touch both areas while working on "archive" features.

## Local Development

### Required services and settings

For full archive work you need:

- MongoDB, including the analytics DB (`nbanalytics`)
- Redis PubSub
- Celery
- Node socket service
- Elasticsearch for browser-tab search
- `ANTHROPIC_API_KEY` for categorization, category splitting, and Archive Assistant
- `NEWSBLUR_URL` aligned with the URL you use for extension OAuth

If you change `NEWSBLUR_URL` or switch to a new custom localhost/worktree URL after migrations already ran, refresh the OAuth application explicitly:

```bash
docker exec -t newsblur_web python manage.py setup_archive_oauth
```

In a worktree, replace `newsblur_web` with `newsblur_web_<worktree-name>`.

### Quick local workflow

1. Start the stack with `make`.
2. Give a dev user archive access if you need the `/archive` UI:

```bash
docker exec -t newsblur_web python manage.py shell -c "
from apps.profile.models import Profile
p = Profile.objects.get(user__username='sclay')
p.is_premium = True
p.is_archive = True
p.save()
"
```

3. Open `https://localhost/reader/dev/autologin/?next=/archive`.
4. Point the browser extension at that server in its options page if you are testing extension sync locally.

### Exercising the stack

- Browse the web with the extension loaded and watch archives appear in `/archive`.
- To inspect stored archive docs:

```bash
docker exec -t newsblur_web python manage.py shell -c "
from apps.archive_extension.models import MArchivedStory
print(MArchivedStory.objects(user_id=1).count())
"
```

- To inspect assistant conversations:

```bash
docker exec -t newsblur_web python manage.py shell -c "
from apps.archive_assistant.models import MArchiveConversation
print(MArchiveConversation.objects(user_id=1).count())
"
```

- To manually rebuild a user's archive search index:

```bash
docker exec -t newsblur_web python manage.py shell -c "
from apps.archive_extension.search import SearchArchive
print(SearchArchive.reindex_user_archives(1))
"
```

### Celery restart rules

Archive work follows the same Celery rule as Ask AI: restart Celery whenever you change code that a task imports or executes.

That includes:

- `apps/archive_extension/tasks.py`
- `apps/archive_extension/search.py`
- `apps/archive_extension/matching.py`
- `apps/archive_assistant/tasks.py`
- `apps/archive_assistant/tools.py`
- `apps/archive_assistant/prompts.py`
- `apps/archive_assistant/models.py`
- any shared helper those tasks call

Restart command:

```bash
docker restart newsblur_celery
```

In a worktree:

```bash
docker restart newsblur_celery_<worktree-name>
```

Node and web code reload separately, so changing `node/archive_assistant.js`, `node/unread_counts.js`, or `media/js/newsblur/views/archive_view.js` does not by itself require a Celery restart.

### Queues and scheduling

- Archive Celery routes:
  - `archive-categorize`
  - `archive-index-elasticsearch`
  - `archive-process-batch`
  - `archive-cleanup-old`
- All four route to `push_feeds`
- `submit_query()` also explicitly queues Archive Assistant work on `push_feeds`
- Worktree Celery automatically prefixes queue names via `newsblur_web/celeryapp.py`

One important nuance: `archive-cleanup-old` exists and is routed, but there is no current `CELERY_BEAT_SCHEDULE` entry for it in `newsblur_web/settings.py`.

### Tests

Relevant test suites:

- `make test SCOPE=apps.archive_extension ARGS="-v 2"`
- `make test SCOPE=apps.archive_assistant ARGS="-v 2"`

Use these before touching archive docs or implementation, because many of the route names and edge cases are already covered there.
