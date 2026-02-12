# NewsBlur Architecture

NewsBlur is a personal news reader that brings people together to talk about the world.
It is a full-stack RSS reader with intelligence (train stories you like/dislike),
social features (follow friends, share stories), and AI capabilities (ask AI, briefings).

## High-Level Overview

```
┌──────────────┐    ┌───────────┐    ┌───────────────┐
│   Browser    │───▶│  HAProxy  │───▶│  Nginx        │
│   (Backbone) │    │  (SSL/LB) │    │  (static/proxy)│
└──────────────┘    └───────────┘    └───────┬───────┘
                                             │
                         ┌───────────────────┼───────────────────┐
                         ▼                   ▼                   ▼
                  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐
                  │  Gunicorn   │    │   Node.js    │    │  Imageproxy │
                  │  (Django)   │    │  (page/text/ │    │  (images)   │
                  │  port 8000  │    │   favicons/  │    │  port 8088  │
                  └──────┬──────┘    │   socket.io) │    └─────────────┘
                         │           │  port 8008   │
                         │           └──────────────┘
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  PostgreSQL  │ │   MongoDB    │ │    Redis     │
│  (relational │ │  (documents/ │ │  (cache/     │
│   metadata)  │ │   stories)   │ │   queues/    │
└──────────────┘ └──────────────┘ │   pubsub)    │
                                  └──────────────┘
        ┌────────────────┘
        ▼
┌──────────────┐     ┌──────────────┐
│Elasticsearch │     │    Celery    │
│  (search/    │     │  (async task │
│   discovery) │     │   workers)   │
└──────────────┘     └──────────────┘
```

## Database Strategy

NewsBlur uses four data stores, each chosen for specific strengths:

### PostgreSQL
Relational data requiring ACID guarantees and complex joins.
- **User accounts** (Django `auth_user`)
- **Feed metadata** (`Feed` — URL, title, subscriber counts, fetch schedule)
- **Subscriptions** (`UserSubscription`, `UserSubscriptionFolders`)
- **Recommendations** (`RecommendedFeed`, `RecommendedFeedUserFeedback`)
- **Push subscriptions** (`PushSubscription` — PubSubHubbub)
- **OAuth tokens** and payment records

### MongoDB
High-volume document storage with flexible schemas.
- **Stories** (`MStory` — title, content, images, compressed with zlib)
- **Starred stories** (`MStarredStory`)
- **Read state** (`RUserStory` — per-user story read/starred tracking)
- **Classifiers** (`MClassifierTitle`, `MClassifierAuthor`, `MClassifierTag`, `MClassifierFeed`, `MClassifierUrl`, `MClassifierText`, `MClassifierPrompt`)
- **Social data** (`MSharedStory`, `MSocialProfile`, `MActivity`)
- **AI responses** (`MAskAIResponse` — cached, zlib-compressed)
- **Briefings** (`MBriefing`)
- **Archived browsing history** (`MArchivedStory` — in separate `nbanalytics` database)
- **Statistics** (`MStatistics`)

### Redis
In-memory cache, message broker, and session store. Production runs four separate
Redis instances; Docker development shares a single instance with numbered databases:

| Instance | DB | Purpose |
|----------|----|---------|
| `redis-user` | 0 | User data cache |
| `redis-user` | 2 | Analytics |
| `redis-user` | 3 | Statistics |
| `redis-user` | 4 | Celery broker and feed scheduling |
| `redis-user` | 6 | Django cache |
| `redis-user` | 10 | Temporary story hashes |
| `redis-story` | 1 | Story hashes |
| `redis-session` | 1 | Feed read state |
| `redis-session` | 2 | Feed subscription state |
| `redis-session` | 5 | Sessions |
| `redis-pubsub` | 0 | Pub/sub messaging |

### Elasticsearch
Full-text search and vector-based discovery.
- **SearchFeed** — Feed metadata search
- **SearchStory** — Story full-text search (premium feature)
- **DiscoverStory** — Related story/feed discovery via embeddings

## Django Apps

All apps live under `apps/`. Each app is a self-contained Django module.

| App | Purpose |
|-----|---------|
| `analyzer` | Intelligence trainer — classifiers that score stories by title, author, tag, feed, URL, text, and AI prompts |
| `api` | External REST API for third-party clients |
| `archive_assistant` | AI chatbot for querying archived browsing history (Claude SDK + RAG) |
| `archive_extension` | Browser extension backend for automatic browsing history capture |
| `ask_ai` | AI-powered story summarization and Q&A (Claude, GPT, Gemini, Grok) |
| `briefing` | AI-generated personalized news briefings with curated sections |
| `categories` | Curated feed categories for bulk subscription and discovery |
| `feed_import` | OPML import/export and external service import (Google Reader, etc.) |
| `mobile` | Mobile web workspace served at `/mobile/` and `/m/` for iOS and Android clients |
| `monitor` | System health monitoring dashboards and Prometheus metrics endpoints |
| `newsletters` | Email-to-RSS — converts email newsletters into subscribable feeds |
| `notifications` | Push notifications (iOS APNS, web push, email) for new stories |
| `oauth` | OAuth integration for extensions, IFTTT, and social account connections (Twitter, Facebook) |
| `profile` | User profiles, premium subscription tiers (Stripe/PayPal), preferences |
| `push` | PubSubHubbub subscriber for real-time feed updates |
| `reader` | Core feed reader — subscriptions, folders, unread tracking, story display |
| `recommendations` | Crowd-sourced feed recommendations with upvote/downvote |
| `rss_feeds` | Feed fetching, parsing, story storage, and feed health management |
| `search` | Elasticsearch integration for full-text story and feed search |
| `social` | Social features — sharing stories, following users, comments, blurblogs |
| `static` | Static pages (about, FAQ, privacy, press), app manifests, and health check endpoints |
| `statistics` | Analytics collection — user activity, feed fetches, performance metrics |

## Request Flows

### Reading stories (River of News)

1. Browser requests `/reader/river_stories` with feed IDs
2. Django view loads `UserSubscription` records from PostgreSQL
3. Story hashes fetched from Redis, then full `MStory` documents from MongoDB
4. Stories scored against user's classifiers (from `analyzer` app)
5. Scored stories returned as JSON to the Backbone.js frontend

### Feed fetching (background)

1. Celery Beat schedules `TaskFeeds` every minute
2. Worker picks feeds due for update based on subscriber count and last fetch time
3. Feed XML/HTML fetched via HTTP, parsed into `MStory` documents
4. New stories stored in MongoDB, story hashes cached in Redis
5. Unread counts updated in `UserSubscription` (PostgreSQL)
6. If PubSubHubbub is active, real-time updates arrive via `push` app instead

### Training (Intelligence)

1. User trains a story attribute (like/dislike a title keyword, author, tag, etc.)
2. Classifier saved to MongoDB (`MClassifierTitle`, `MClassifierAuthor`, etc.)
3. On next story load, each story is scored: +1 (focus), 0 (neutral), -1 (hidden)
4. Classifiers can be scoped to a feed, a folder, or global

### Ask AI

1. User submits a question about a story
2. Request queued as a Celery task (`ask_ai.tasks`)
3. Worker sends story content + question to selected AI provider
4. Response cached in MongoDB (`MAskAIResponse`) with zlib compression
5. Subsequent identical queries return the cached response

## Celery Task Pipeline

Workers process async jobs across dedicated queues:

| Queue | Purpose |
|-------|---------|
| `work_queue` | Default queue for general tasks |
| `new_feeds` | Processing newly added feeds |
| `push_feeds` | PubSubHubbub real-time updates |
| `update_feeds` | Scheduled feed fetching |
| `search_indexer` | Elasticsearch indexing |
| `discover_indexer` | Discovery/embedding indexing |

**Periodic tasks** (Celery Beat):
- Feed scheduling — every 1 minute
- Broken feed cleanup — every 6 hours
- Statistics collection — every 1 minute
- Briefing generation — every 15 minutes
- Premium expiration — every 24 hours

## Frontend Architecture

The frontend is a **Backbone.js** single-page application.

```
media/js/newsblur/
├── reader/            # Main reader UI (~30 modules)
│   ├── reader.js      # Central controller (routes, state, modals)
│   └── reader_*.js    # Feature modules (classifier, preferences, etc.)
├── models/            # Backbone models and collections
│   ├── stories.js     # Story model
│   ├── feeds.js       # Feed collection
│   └── folders.js     # Folder tree
├── views/             # Backbone views (~44 modules)
├── common/            # Shared utilities
├── social_page/       # Blurblog/social page UI
└── payments/          # Stripe/PayPal integration
```

**Conventions:**
- JavaScript uses **snake_case** (matching the Python codebase)
- Asset pipeline: Django Pipeline with Closure Compiler (JS) and Lightning CSS
- Global namespace: `NEWSBLUR.reader` (controller), `NEWSBLUR.assets` (data)

## Premium Tiers

| Tier | Feeds | Unread Window | Notable Features |
|------|-------|---------------|------------------|
| Free | 64 | 14 days | Basic reading |
| Premium | 1,024 | 30 days | Search, notifications, AI |
| Archive | 4,096 | Unlimited | Full history retention, text classifiers |
| Pro | 10,000 | Unlimited | 5-min fetch, text classifiers |

## Development

- **Docker Compose** runs all services locally
- Web and Node servers auto-reload on code changes
- Celery workers must be restarted manually after code changes
- Git worktrees supported for parallel development (see `CLAUDE.md`)
- Tests: `make test SCOPE=apps.<app_name>`
- Linting: `make lint` (isort, Black, flake8)
