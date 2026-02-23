# Changelog

## February 2026 Release (December 2025 – February 2026)

### New Features

- **Story Clustering** — Groups duplicate and near-duplicate stories across feeds using Elasticsearch semantic matching, with rich cluster cards in story detail view and per-user preferences. Available to Archive subscribers.
- **Ask AI** — Ask questions about any story with answers from multiple AI providers (GPT, Gemini, Claude, Grok). Includes model selector, thinking mode toggle, and tiered weekly limits (free: 1/week, premium: 3/week, archive: 100/day).
- **Daily Briefing** — AI-generated editorial summaries delivered on a configurable schedule with per-section toggles, writing style selection, AI model choice, and email-compatible rendering with inline favicons and section icons.
- **Discover Sites** — Find related feeds from any feed or folder. Try-feed mode lets you preview a feed's stories with a subscribe banner before committing.
- **Trending Sites** — See which feeds are gaining subscribers over the past day, week, and month with a segmented time control and dark mode support.
- **Custom Icons** — Upload images, choose from 200+ preset icons, pick an emoji, or set a color for any feed or folder. Supported on web, iOS, and Android.
- **Archive Extension** — Capture browsing history into NewsBlur for AI-powered full-text search. Includes OAuth authentication, voice input, conversation history, and real-time WebSocket streaming.
- **YouTube Captions** — Auto-enable closed captioning on embedded YouTube videos across all feeds.
- **Disable Social** — New preference to hide all social features (blurblogs, comments, shared stories) from the interface.
- **Global Intelligence Training** — Train classifiers at site, folder, or global scope. Folder and global scopes let a single classifier affect all matching feeds. Available to Archive subscribers.
- **Per-Feed Auto-Mark-Read** — Set custom "days of unread" thresholds per feed or per folder to automatically mark older stories as read. Available to Archive subscribers.
- **Regex Classifiers** — Intelligence Trainer now supports exact phrase and regular expression matching for titles, authors, tags, and URLs. Regex training available to Pro subscribers.
- **Growth Prompts** — Gentle upgrade nudges for free users after adding 5+ feeds or reading 20 stories, shown at most once per month.

### Improvements

- **Login & Signup Redesign** — Frosted glass card layout with dark theme applied to all static and authentication pages.
- **Welcome Page Redesign** — New hero section with WebGL animated background, liquid glass controls, light/dark themes, and updated platform sections.
- **Premium Dialog Redesign** — Separated premium upgrade into a dedicated modal with Free, DIY, Premium, Archive, and Pro tiers showing feed limits and feature comparisons.
- **Intelligence Trainer Overhaul** — Added URL classifiers, Manage Training tab with feed/folder filters, classifier counts on save, tooltips, and a compact combined layout.
- **Dark Theme Expansion** — Dark mode now covers embedded statistics, welcome page, archive view, Manage Training badges, and login pages.
- **Search Improvements** — Phrase queries with quoted strings, case-insensitive search highlighting, hybrid semantic search fallback, and special character escaping.
- **ScrapingBee Fallback** — Feeds blocked by Cloudflare are now retried through ScrapingBee when first added.
- **Saved Story Tags** — Rename and delete saved story tags directly from the sidebar.
- **Invoices** — Printable invoice feature added to payment history.
- **Feed Chooser Cleanup** — Simplified to feed selection only, with premium upgrade logic moved to the new premium modal.
- **Collapse/Expand All Folders** — New toggle in All Site Stories to collapse or expand every folder at once.

### Bug Fixes

- Fix XSS vulnerabilities in cluster rendering, story lookup, and stale Redis members.
- Fix blank iOS statistics modal caused by missing JS globals and unguarded theme calls.
- Fix WebSocket disconnects on iOS by correcting EIO4 protocol handling and session lifecycle.
- Fix feed merge bugs that caused muted feeds and data loss.
- Fix imageproxy OOM crashes with tiered caching and memory limits.
- Fix duplicate Stripe webhook emails on premium tier upgrades.
- Fix SVG self-closing tags being mangled in feed content.
- Fix saved stories always showing as read instead of actual read/unread status.
- Fix Elasticsearch ConnectionTimeout errors in search queries.
- Fix search highlighting stop words like "the" appearing across all content.
- Fix RSS feed encoding by normalizing header keys to lowercase.
- Fix downtime root causes: integer overflow in story IDs, duplicate key races, and thundering herd on deploys.
- Fix PayPal IPN handlers to recognize recurring_payment_id field and handle missing custom_id.
- Fix story page alignment and "Read the whole story" expander positioning.
- Fix duplicate daily briefing emails with Redis distributed locks.
- Fix folder-scoped classifiers showing from wrong folders in Train dialog.
- Fix MStarredStoryCounts race condition in adjust_count.
- Fix relative image URLs not resolving by making them absolute in feed content.
- Fix stale story responses when switching folders quickly on iPad.

### iOS

- **OS 26 Support** — Full compatibility with the latest iOS, including new navigation bars, scroll fixes, iPad compact layout, split column support, transparent toolbars, and Mac Catalyst improvements.
- **Ask AI** — Native Ask AI dialog with provider selection, streaming answers, and theme-aware styling.
- **Discover Sites** — Browse related feeds with try-feed preview and subscribe banner.
- **Custom Icons** — Set custom icons on feeds and folders, synced from the server.
- **Redesigned Login** — Metal shader wave animation with frosted glass card on the login screen.
- **Sheet Presentation** — Unified modal dialogs with sheet presentation and grabber handles across iPhone and iPad.
- **Premium Pro Tier** — Added Pro tier option to the iOS Premium Upgrade dialog.
- **Mac Catalyst** — Auto-hide sidebar below 900pt, trackpad swipe gestures, dismiss modals via overlay tap and escape key.
- **Read Time Tracking** — Track seconds-read telemetry with idle detection for accurate reading time.
- **Auto Theme** — Default theme changed from light to auto (follows system appearance).
- **Memory Improvements** — PINCache cost limits and improved cleanup to reduce memory pressure.
- **Draggable Column Divider** — Interactive grab handle for resizing the feeds/stories split on iPad.

### Infrastructure

- **Grafana & Prometheus** — New dashboards and metrics for story clustering, LLM costs (per-model daily tracking), trending subscriptions, regex classifiers, deleted users, and database replication lag.
- **IP Rate Limiting** — Soft-launch rate tracking with scanner detection middleware and per-IP Prometheus metrics.
- **Task Deduplication** — Deduplicate compute-story-clusters tasks in Celery work queue to prevent redundant processing.
- **Database Replication Monitoring** — New panels tracking replication lag for Redis, Postgres, and MongoDB.
- **HAProxy Health Checks** — Tuned check intervals and thresholds to prevent false DOWNs during deploys.
- **CSS Minification** — Replaced yuglify with lightningcss for faster, more reliable CSS compilation.
- **Celery Queue Isolation** — Worktree-specific Celery containers with isolated task routing and beat scheduling.
- **Consul Alerting** — Service health alerts linked to Grafana dashboard panels with 15-minute continuous downtime threshold.
- **MapReduce Removal** — Replaced MongoDB MapReduce with aggregation pipelines for starred story counts.
- **Sentry Alerts** — Added reduce steps and proper threshold expressions to Sentry alert rules.
