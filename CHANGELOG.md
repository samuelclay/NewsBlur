# NewsBlur Changelog - 2026

## Daily Briefing

- AI-powered editorial summaries delivered on your schedule: once or twice daily, with time-of-day-aware titles and weekly scheduling options
- Configurable briefing sections with toggleable categories, custom keyword sections, and per-section summaries
- Full-pane onboarding view introduces new users to the briefing feature
- Briefing preferences popover with radio-style writing picker, section icons, notification controls, and AI model selector
- Briefing sections expandable with per-section filtering and classifier badge pills showing "Based on your interests"
- Email-compatible rendering with inline styles, embedded favicons, section icons as data URIs, and clickable story links
- Favicon-as-bullet indentation for editorial and headlines briefing styles
- Sticky headers and feed diversity across reader-value sections
- Smart deduplication with Redis distributed locks to prevent duplicate briefings
- Folder filter includes subfolders and prevents silent fallback to all feeds
- All briefing sections enabled by default with custom section names in sidebar
- Briefing reloads on re-click, matching standard feed behavior
- Briefing stories excluded from all dashboard modules to avoid replacing river story titles
- Comprehensive test suite with 145 tests

## Archive Extension

- Browser extension for capturing browsing history with AI-powered semantic search
- OAuth authentication with authorization code flow and auto-setup via migration
- WebSocket streaming for real-time AI assistant responses with tool result streaming
- Conversation history sidebar for the Archive Assistant
- Voice input with live audio feedback for natural language search
- RSS story tools and shared story tools available in assistant
- Tabbed category manager with drag-drop merge and AI-powered split
- Inline date picker with relative dates and custom range popover
- Filter intersection for sidebar with timezone-aware date buckets
- Real-time WebSocket updates for live archive ingestion status
- Dismissible extension download promo and full-width archive view
- Idle detection for accurate reading time tracking
- Staff-only launch gated behind archive subscription tier

## Intelligence Trainer Overhaul

- Compact trainer dialog with combined sections and unified input supporting exact phrase and regex modes
- Manage Training tab with feed/folder dropdown, search filters, and scope-based grouping (site/folder/global)
- URL classifier with exact phrase and regex modes, displaying matched URL portions in story headers
- Global and folder-scoped intelligence trainers with scope controls and propagation
- Classifier count shown on save button with real-time UI updates
- Tooltips, popovers, and validation improvements throughout the trainer UX
- Regex training gated to Premium Pro tier
- Folder-scoped classifiers split from global section in Manage Training
- Delete intelligence training classifiers section added to Account dialog
- Scope-based classifier metrics tracked in Prometheus and Grafana
- Fix classifier cross-contamination between trainer tabs, score=0 persistence bug, and legacy query edge cases

## Per-Feed Auto Mark as Read

- Per-feed and per-folder auto-mark-read settings for Premium Archive users
- Auto Mark as Read option in folder feed options popover
- Feed settings dialog redesigned to match popover style
- Days of unread preference redesigned with segmented control and slider
- Non-archive users see grayed-out preference with upgrade link
- Folder inheritance and subfolder support for auto-mark-read cutoffs
- N+1 query fix for river stories performance

## Welcome Page Redesign

- Dark theme with liquid glass controls and animated transitions
- WebGL animated background
- Responsive layout with light/dark theme support and smooth transitions
- Redesigned hero and platform sections with 6 new sub-features
- Tryout signup banner with theme-aware styling and smooth close transition
- Three-pane mobile layout for anonymous tryout with improved desktop tryout UX
- Direct access via /welcome route

## Login/Signup Redesign

- Frosted glass card design for login and signup forms
- Dark theme applied consistently to all static pages

## Custom Icons

- Custom folder and feed icons with upload, preset icon library (200+ icons), emoji picker, and color picker
- SVG upload support with format hints
- Feed and folder icons exposed in flat feeds endpoint for iOS and Android
- Custom icons hidden appropriately for saved story tags and social feeds
- Dark mode CSS for custom icons

## Disable Social Features

- Preference to hide all social features from the NewsBlur UI
- Card-based preference UI in settings
- Hides sharing, social feeds, blurblogs, Twitter/Facebook crosspost buttons, and friend activity

## Ask AI Enhancements

- Centralized model configuration as single source of truth in providers.py
- Thinking mode toggle for supported models
- Improved error messages for invalid or missing API keys
- Model dropdown scroll fix and undefined model on re-ask resolved
- GPT 5.2 support and unified weekly limits across tiers
- Historical model tracking in Prometheus metrics after model retirement

## Saved Story Tags

- Rename and delete saved story tags
- Fix saved stories to show actual read/unread status instead of always appearing read

## Premium & Billing

- Printable invoice feature for payment history
- Grandfathering simplified to single tier: 1-year grace period for users over 1024 feeds
- Growth prompts shown only once per user with hide button on trial module
- Cap auto-enable feeds at tier limit on upgrade, relax pro feed decay
- Fix premium tier downgrade bugs for PayPal archive/pro subscribers
- Fix PayPal IPN handlers to recognize recurring_payment_id field
- Fix PayPal webhook KeyError when custom_id/custom field is missing
- Ignore Stripe/PayPal webhooks for non-NewsBlur products
- Prevent duplicate emails from concurrent Stripe webhooks on tier upgrades
- Retry Stripe invoice and reactivate subscription helpers
- Staff email notifications for new archive upgrades
- Premium Archive and Pro user charts added to Grafana dashboard

## Infrastructure & Ops

### Performance & Reliability
- Fix slow page loads for high-latency connections
- Fix deploy downtime by waiting for HAProxy health checks and tuning thresholds
- Fix downtime root causes: integer overflow, duplicate key races, and thundering herd
- Fix imageproxy OOM crashes with tiered cache and memory limit
- Replace yuglify with lightningcss for CSS minification
- Replace MapReduce with aggregation pipelines for starred story counts
- Batch analytics cleanup deletes to prevent MongoDB memory exhaustion
- ScrapingBee fallback when adding feeds blocked by Cloudflare
- Retry feed discovery without User-Agent on HTTP 202 and empty responses

### Search
- Hybrid semantic search fallback for feed search
- Fix search highlighting stop words appearing everywhere
- Escape Elasticsearch special characters in feed autocomplete queries
- Handle Elasticsearch ConnectionTimeout gracefully

### Monitoring & Metrics
- Centralized LLM cost tracking with Redis-backed Prometheus metrics
- Database replication lag monitoring for Redis, Postgres, and Mongo
- Deleted user tracking with Prometheus and Grafana dashboard
- Consul service health alerts with dashboard integration
- Sentry alert rules with reduce steps for multi-series data
- IP rate limiting with soft launch mode and Prometheus metrics
- Discover usage tracking in Prometheus/Grafana
- Production health check tooling and downtime investigation playbook

### DevOps & Tooling
- Git worktree improvements: idempotent startup, Celery queue isolation, worktree-specific Beat scheduler
- Dev autologin endpoint and Chrome SSL bypass for local development
- MCP response size limit hook for large responses
- CI retry logic for transient network failures and --keepdb for test teardown
- Ansible swap role for Grafana stability on metrics server
- Android Digital Asset Links for autofill credential sharing
- 1Password association fix with AASA JSON and Alpha bundle ID

### Feed Processing
- Fix RSS feed encoding by normalizing header keys to lowercase
- Fix encoding detection in TEXT view readability and Story view page fetcher
- Fix SVG self-closing tags being mangled in feed content
- Use date_modified as fallback for JSON feeds missing date_published
- Make relative image URLs absolute by modifying soup elements directly
- Update user agent strings to modern Chrome/Edge 143
- Add NetNewsWire to platform user-agent parser
- Show "Untitled" for stories with no title, content, or permalink

### UI Polish
- Dark mode styles for Trending Sites view
- Segmented control replacing time selector dropdown
- Collapse/expand all folders toggle for All Site Stories
- Server indicator dot always green when connected
- Loading bar visibility fixes to prevent flicker in Focus mode
- Taskbar info converted to flexbox layout
- Thinking icon replaced with recognizable Lucide brain SVG
- Taller settings modals and tab border fixes
