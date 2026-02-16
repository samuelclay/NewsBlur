# Changelog

All notable changes to NewsBlur from January–February 2026.

## Daily Briefing

A new AI-powered editorial briefing feature that delivers personalized daily summaries of your feeds.

### Core Feature
- Add Daily Briefing feature with AI-powered editorial summaries (`f2aa43f`)
- Redesign briefing with reader-value sections, sticky headers, and feed diversity (`3282b5b`)
- Add expanded briefing preferences, staff-only gating, and fix unread count persistence (`f8580cc`)
- Overwrite existing briefing on regenerate and add preferences gear icon (`05a5244`)
- Add expandable briefing sections with per-section summaries and filtering (`884542f`)
- Add configurable briefing sections with toggleable UI and custom prompts (`7b945b9`)
- Redesign briefing preferences UI with radio-style writing picker, section icons, and better defaults (`a2ab7b2`)
- Move briefing settings into two-column popover with read filter and weekly scheduling (`f1adeda`)
- Add notification controls to briefing preferences and onboarding UI (`bf23ddf`)
- Move briefing onboarding into full-pane view covering story titles and detail areas (`efdd37a`)
- Add configurable AI model selection for daily briefing (`4aa0a99`)

### Scheduling & Delivery
- Use fixed delivery times for briefing slots instead of activity detection (`c127455`)
- Fix briefing scheduling: local timezone dedupe, twice-daily morning slot, weekly preferred day, and feed view positions (`698b6ea`)
- Add time-of-day briefing titles, fix 2x daily dedup, remove AI references (`82b018d`)
- Fix briefing sections being capped at 3 and twice-daily scheduling bug (`c5e5df9`)
- Fix triple daily briefing by adding Redis distributed locks (`952ce0b`)
- Fix briefing date timezone and smooth collapse animation (`a61ebcc`)

### Email & Rendering
- Redesign daily briefing with inline styles for email-compatible rendering (`e13a0cb`)
- Inline briefing icons as data URIs, add model/stats debug footer (`cddd9108`)
- Embed briefing favicons and section icons server-side for email support (`78cc3ae`)
- Bump daily briefing email font size from 16px to 18px for better readability (`7f288bc`)
- Add clickable story links, favicon tooltips, and fix briefing email icon (`13648042`)

### Visual Polish
- Add favicon-as-bullet indentation for editorial and headlines briefing styles (`4a2501d`)
- Fix briefing favicon offset, indentation, and pill sizing for editorial/headlines (`a0c46d3`)
- Polish briefing popover typography and match settings button to feedbar style (`823d5b7`)
- Fix briefing preferences UI: checkbox alignment, close icon, icon centering, and hint popover dismissal (`af79d5f`)
- Replace abstract thinking icon with recognizable Lucide brain SVG (`747b018`)
- Revert SVG source colors, use CSS grayscale filter for briefing icons (`76f7d11`)
- Normalize briefing section icon colors to consistent #95968E gray (`362fdba`)
- Fix OpenAI reasoning model token limits, add gray briefing icons (`fcaae19`)
- Add classifier badge pills to briefing "Based on your interests" section (`7973870`)

### Bug Fixes
- Fix briefing crash by calling secure_image_urls on Feed instead of MStory (`9cdf3cc`)
- Fix three Daily Briefing bugs: nested folder matching, disabled sections, and custom prompts (`50ae651`)
- Fix daily briefing JS errors from missing secure_image_urls and uninitialized views (`b14fdb1`)
- Fix briefing folder filter to include subfolders and prevent silent fallback (`8be308c`)
- Fix briefing folder selection, remove Pro gating from model selector (`2a3a70e`)
- Fix Daily Briefing stories replacing dashboard river story titles (`0666e47`)
- Fix disabled sections still appearing in Daily Briefing sidebar (`1996a09`)
- Prevent briefing view scroll reset on real-time feed updates (`3b6473c`)
- Handle briefing progress messages arriving as user:update events (`6661996`)
- Fix missing ensure_briefing_feed import in briefing views (`132e93b`)
- Fix briefing popover layout, story count labels, and null folder crash (`167bab6`)
- Exclude daily briefing stories from all dashboard modules (`9403759`)
- Normalize and validate briefing section keys from AI output (`2f73553`)
- Rename custom sections to keyword sections and separate from section checklist (`e611505`)
- Enable all briefing sections by default and fix custom section names in sidebar (`3f17f12`)
- Add Ask AI thinking mode toggle and fix briefing lock TTL (`d9a63f1`)
- Add comprehensive test suite for Daily Briefing feature (145 tests) (`b5a410c`)

## Intelligence Trainer Overhaul

A major redesign of the Intelligence Trainer with global/folder scope, URL classifiers, regex support, and a new Manage Training tab.

### Scope-Based Classifiers
- Launching new intelligence trainer (`84a82ac`)
- Add global intelligence trainers with scope controls for classifiers (`736071f`)
- Split folder-scoped classifiers out of global section in Manage Training (`133e03c`)
- Separate story trainer classifiers into scope groups (site/folder/global) (`44ca627`)
- Move scoped classifiers to Archive tier with manage training scope filters (`5bdb69c`)
- Fix global scope propagation bug in classifier save (`d5c292b`)
- Fix scope change persistence, deferred saves, and duplicate text classifiers (`07b8d17`)
- Fix scoped classifier edge cases: scope changes, legacy queries, manage tab saves (`7679d73`)
- Fix folder-scoped classifiers showing from wrong folders in Train dialog (`53458e7`)
- Fix folder-scoped classifier scoring: JS folder lookup, missing folder_feed_ids, and archive gating (`c9db40e`)
- Include global and folder-scoped classifiers in unread count recalculation (`80223b8`)
- Move user_is_pro check to callers, remove from classifier function signatures (`cd47fad`)
- Remove redundant (user_id, scope) indexes from classifier models (`dfdbc67`)
- Add scope-based classifier metrics to Prometheus and Grafana (`c788882`)
- Fix classifier removal bug where score=0 classifiers persist in database (`a61ebcc`)
- Add strict=False to MClassifier models for forward-compatible field handling (`053a7058`)

### URL & Regex Classifiers
- Add URL classifier with exact phrase and regex modes to Intelligence Trainer (`b032a14`)
- Add URL classifiers throughout codebase and fix Manage Training stateless tracking (`36e6e1d`)
- Add real-time URL classifier updates and display matched URL portions in story header (`3294062`)
- Add unified input with exact phrase and regex mode toggle for classifiers (`64f685e`)
- Add URL and regex classifier support to bulk save function (`6691c1c`)
- Fix critical bugs in regex classifier implementation (`6f4e33b`)
- Add regex classifier counts to Prometheus metrics (`42f095b`)
- Add url/url_regex to all intelligence dicts and fix JS classifier structure (`a85dc66`)
- Add regex training feature to Premium Pro tier and fix included status icon (`40afa38`)
- Add regex filter support to Intelligence Trainer (`365f4d0`)
- Fix URL classifier label to display as 'URL:' instead of 'Url:' (`c244f10`)
- Add is_regex index to classifier models for faster Prometheus scraping (`5693c24`)

### Manage Training Tab
- Add Manage Training tab to Intelligence Trainer dialog (`1374d17`)
- Add feed/folder dropdown and search filters to Manage Training (`6da5e91`)
- Improve Manage Training tab filter controls and layout (`968ad98`)
- Fix dark mode contrast for filter count badges in Manage Training tab (`b86fe54`)
- Fix filter toggle bug and icon colors in Manage Training tab (`7a784af`)
- Move Saved message to left of button in Manage Training tab (`3eca097`)
- Fix classifier cross-contamination between trainer tabs (`fe78a97`)
- Fix tag classifier click not updating UI due to HTML entity mismatch (`f9f1044`)
- Swap filter row order: folder/search on top, show/types on bottom (`d92d6e7`)

### UI & UX
- Compact Intelligence Trainer dialog with combined sections (`be4fc88`)
- Improve Intelligence Trainer UX with tooltips, popovers, and validation (`d80748d`)
- Show classifier count on save button in Intelligence Trainer (`0e009f8`)
- Fix Intelligence Trainer header layout with favicon, title, and subscriber count (`2c8da3a`)
- Add delete intelligence training classifiers section to Account dialog (`5c6f341`)

### Blog Posts
- Intelligence Trainer Overhaul blog post (`9ec2c95`, `2c8da3a`, `466b520`)
- Add blog post for Manage All Your Training feature (`e62c2f0`)
- Add blog post for global and folder-scoped intelligence training (`f6233651`)

## Archive Extension

A browser extension for capturing browsing history and AI-powered search across your reading archive.

### Core Feature
- Add Archive Extension for browsing history capture and AI-powered search (`eef00157`)
- Add OAuth authentication and Elasticsearch search to Archive Extension (`e8fb669`)
- Add comprehensive test suite for Archive Extension (`54e84ef`)
- Launching archive extension for staff (`5683c3e`)
- Make Reading Archive staff-only and use main MongoDB (`a19a0d4`)

### Archive Assistant
- Add Archive Assistant with AI-powered chat for searching your archive (`156f049`)
- Enable true streaming for Archive Assistant with UI fixes (`156f049`)
- Improve Archive Assistant chat scroll pinning and multi-segment rendering (`23aa70f`)
- Add conversation history sidebar to Archive Assistant (`651f114`)
- Add RSS story tools and tool result streaming to Archive Assistant (`e87cb68`)
- Add current date context and shared story tools to Archive Assistant (`0cbe499`)
- Parallelize Archive Assistant tool execution for faster responses (`2700e18`)
- Add voice input to Archive Assistant with live audio feedback (`53e63858`)
- Add browser extension download links to Archive Assistant (`e32ed6a`)
- Migrate Archive Assistant from polling to WebSocket streaming (`0dd9a4a`)
- Fix Archive Assistant search bug and improve UI styling (`7489da2`)

### Archive UI
- Redesign archive date picker with inline relative dates and custom range popover (`d72d59b`)
- Add filter intersection for archive sidebar with timezone-aware date buckets (`fb6e735`)
- Improve Archive view with animations, author field, and real-time categories (`f7d4dc7`)
- Fix archive animation bounce and add WebSocket handler for categories (`0dc3ae0`)
- Improve animations, add content preview, and filter sidebar on search (`0dc3ae0`)
- Fix Archive view to take full width using jQuery UI Layout API (`07923df`)
- Make Archive view take full width of content area (`3fa8ae2`)
- Remove archive layout animations and add dismissible extension promo (`459ac21`)

### Archive Backend
- Add idle detection to archive extension for accurate reading time (`a28d0603`)
- Add real-time WebSocket updates for Archive Extension (`7489da2`)
- Refactor category manager to use standard NewsBlur modal pattern (`0cbe499`)
- Add tabbed category manager with drag-drop merge and AI split (`f3286a8`)
- Use semantic field names in category/domain aggregation (`a3a4ee9`)
- Fix get_domains view to use new domain key from aggregation (`cf8a22c`)
- Add UTC timezone suffix to ISO date strings in archive APIs (`b811c39`)
- Refactor UTC datetime formatting to use utility function (`8cb3bfb`)
- Fix archive_assistant tests to use proper public API (`ceb99d5`)
- Remove outdated test expecting ingest to require archive subscription (`7e95d12`)
- Move archive task routes from archive_queue to push_feeds (`2d87733`)

### Archive OAuth
- Auto-setup Archive extension OAuth via migration (`dd10bb1`)
- Fix Archive extension OAuth to use authorization code flow (`4694612`)
- Add debugging and better error handling for Archive OAuth flow (`af3e9671`)
- Fix Firefox OAuth token save and improve error handling (`a7ab195`)

### Archive Tests
- Add comprehensive test suite for Archive Extension (`54e84ef`)
- Fix flaky CI test by mocking MStory.objects in archive sync tests (`69c4bb1`)
- Add tests for Premium Archive Redis throttling (`0f664c6`)
- Throttle Redis during Premium Archive upgrade (`b1e58e8`)

## Ask AI Enhancements

Improvements to the Ask AI feature including new models, cost tracking, and better error handling.

- Update Ask AI: GPT 5.2, unified 1/week limits, privacy note (`58851c1`)
- Centralize Ask AI model config into single source of truth in providers.py (`9c2e8a9`)
- Add Ask AI thinking mode toggle and fix briefing lock TTL (`d9a63f1`)
- Fix model dropdown scroll and undefined model on re-ask click (`f63ced6`)
- Add centralized LLM cost tracking with Redis-backed Prometheus metrics (`a19a0d4`)
- Fix LLM cost tracking for short model names and add embedding costs (`cc8d876`)
- Track historical models in Ask AI metrics after model retirement (`27e5ef2`)
- Add llm_costs job to production Prometheus config (`8b3e2bd`)
- Fix AttributeError in Ask AI monitor by using unified WEEKLY_LIMIT (`4a038767`)
- Improve Ask AI error messages for invalid/missing API keys (`a690140`)
- Update Ask AI blog post with current models and opt-out section (`1276a1e`)

## Custom Icons

New feature allowing custom icons for feeds and folders with upload, preset icons, emoji, and color picker.

- Add custom folder icons with upload, preset icons, emoji, and color picker (`ad15989`)
- Add custom feed icons with same features as folder icons (`7836399`)
- Add expanded icon picker with 200+ new icons and CSS fixes (`1bc6f4f`)
- Fix folder icon upload and improve upload UI styling (`78903b9`)
- Add custom folder and feed icon support for Android (`f9224745`)
- Add custom feed and folder icons to flat feeds endpoint for iOS/Android (`b56ca21`)
- Add SVG upload support, format hints, taller settings modals, and fix tab border (`82b0a49`)
- Refactor icon handling and validation (`5d7b4e8`)
- Fix filled icons color consistency and misbehaving site dialog order (`c1ec194`)
- Fix upload preview showing empty on Feed Icon tab load (`c244f61`)
- Hide Feed Icon tab for shared/social feeds (`aa3ff07`)
- Hide Feed Icon tab for saved story tags (`a204e07`)
- Move custom folder icon dark mode CSS to darkmode.css (`045c569`)
- Remove unused load_folder_icons endpoint (`d100289`)
- Hide subscriber count for saved tags and social feeds (`c244f61`)
- Prevent subscriber count and reset link from wrapping in modal header (`eec55be`)
- Remove folder icon section from feed options popover (`5f02247`)

## Welcome Page & Login Redesign

Complete redesign of the welcome page and login/signup experience.

- Redesign welcome page with dark theme, liquid glass controls, and animated transitions (`de71fc2`)
- Add WebGL animated background for welcome page (`60c9f86`)
- Redesign welcome page hero and platform sections (`fcaae19`)
- Add light theme, responsive layout, and smooth theme transitions for welcome page (`51f0395`)
- Add tryout signup banner with light/dark theme and smooth close transition (`088b320`)
- Add /welcome route for direct access to the welcome page (`3c4f0a3`)
- Update welcome page features heading and add 6 new sub-features (`91ecc37`)
- Refine welcome page sub-features: cover-fit images, remove redundant app entries, swap order (`656ef1e`)
- Fix sub-feature layout with flexbox and add mobile viewport meta tag (`205fc9f`)
- Add dark mode styling for welcome page footer (`d12c3e1`)
- Redesign login/signup as frosted cards and apply dark theme to all static pages (`5c355d0`)
- Add three-pane mobile layout for anonymous tryout and fix desktop tryout UX (`774277b`)
- Dark mode (`91dcbca`)

## Per-Feed Auto Mark Read

New Premium Archive feature for automatic mark-as-read settings per feed and folder.

- Add per-feed auto mark read feature to Premium Archive tier (`877e114`)
- Add Auto Mark as Read to folder feed options popover (`4bebd7c`)
- Add per-feed and per-folder auto-mark-read settings for archive users (`dd10bb1`)
- Fix per-feed auto mark read filtering for cached stories and subfolders (`28d94cf`)
- Fix auto mark read cutoff and folder inheritance issues (`7c8a4a7`)
- Fix ceaeac96: N+1 query in get_auto_mark_read_cutoff for river stories (`ceaeac9`)
- Redesign days of unread preference with segmented control and slider (`55e23091`)
- Redesign feed settings dialog auto-mark-read to match popover style (`34a4fd`)
- Gray out days of unread preference for non-archive users with upgrade link (`faf1a43`)
- Add blog post for per-feed auto-mark-as-read feature (`55e23091`)

## Saved Story Tags

Improvements to saved story tag management.

- Add rename and delete functionality for saved story tags (`ee51c61`)

## Premium & Billing

Premium subscription management, billing fixes, and grandfathering logic.

### Grandfathering
- Add grandfather_expires field and daily notification task for feed limits (`6df733e`)
- Simplify grandfathering: two-tier system for existing premium users (`4197e9f`)
- Fix grandfathering: only apply to users over 1024 feeds (`0b5e644`)
- Simplify grandfathering to single tier: 1 year grace period for all users over 1024 feeds (`1d87bcf`)
- Add grandfathered users metric to Prometheus/Grafana (`2d08ce0`)

### Billing & Payments
- Prevent duplicate emails from concurrent Stripe webhooks on tier upgrades (`4181413`)
- Fix PayPal IPN handlers to recognize recurring_payment_id field (`20bda9f`)
- Fix PayPal webhook KeyError when custom_id/custom field is missing (`9ac3e18`)
- Ignore Stripe/PayPal webhooks for non-NewsBlur products (Crabigator) (`fa6a65f`)
- Fix premium tier downgrade bugs for PayPal archive/pro subscribers (`d5c292b`)
- Fix PaymentHistory.MultipleObjectsReturned error in setup_premium_history (`3647eeb`)
- Add retry_stripe_invoice and reactivate_stripe_subscription helpers (`005b309`)
- Add staff email for new archive upgrades, guard pro/archive emails against renewals (`bff7a9a`)
- Add printable invoice feature for payment history (`c4d1ea4`)
- Cap auto-enable feeds at tier limit on upgrade, relax pro feed decay (`50554311`)

### Premium UI
- Separate one-time grandfathering from daily email task (`1e9d0ce`)
- Add hide button to trial module and style all module hide buttons (`de906ec`)
- Show growth prompts only once per user, ever (`cb3402d`)
- Add Premium Archive and Pro user charts to top of NewsBlur dashboard (`f6878d2`)

## Feed Discovery

Improvements to feed discovery and subscription flow.

- Rename discover button label to "Related Sites" and add it to folder view (`e2f29e0`)
- Move try feed Subscribe/Follow/Sign up buttons to story titles list (`b05d730`)
- Add ScrapingBee fallback when adding feeds blocked by Cloudflare (`21ab9de`)
- Retry feed discovery without User-Agent on HTTP 202 and empty responses (`01df93f`)
- Escape Elasticsearch special characters in feed autocomplete queries (`880b603`)
- Fix search highlighting stop words like "the" appearing everywhere (`6d94c33`)
- Fix feed search and add hybrid semantic search fallback (`797834`)
- Make Trending Sites staff-only with subtle badge (`a00cd6f`)

## Social Features

- Remove Twitter and Facebook crosspost buttons from share dialog (`c788822`)
- Add disable social preference to hide all social features in the UI (`be4fc88`)
- Redesign disable social preference with card-based UI (`c03f1cd`)
- Hide additional social elements when social features disabled (`162bc3a`)
- Add delete shared stories feature with inline story counts (`0873d82`)

## Infrastructure

### Deployment & Docker
- Fix deploy downtime by waiting for HAProxy health checks and tuning check thresholds (`7dfcfc2`)
- Fix staging 503s: add max_requests_jitter and bump staging max_requests (`fc47d8f`)
- Increase staging haproxy health check tolerance to prevent false DOWNs (`e4d69a9`)
- Add nginx healthcheck to fix haproxy startup race condition in worktrees (`70fb449`)
- Increase HAProxy server timeout from 10s to 30s (`d3354c2`)
- Replace yuglify with lightningcss for CSS minification (`d60a59b`)
- Add validation and increase heap size for static asset compilation (`0c210b4`)
- Increase Node.js heap size for yuglify in deploy container (`d0d9c8d`)
- Convert local assets from png to webp (`af10e11`)
- Remove references to deleted CSS files from assets.yml (`93c25b7`)

### Worktrees
- Add worktree-specific Celery Beat for development periodic tasks (`6af45301`)
- Add Celery queue isolation for git worktrees (`93d1f32`)
- Disable beat scheduler and prefix task routes in worktree Celery (`973fa09`)
- Exclude update_feeds queue from worktree celery containers (`d7b94bc`)
- Change worktree haproxy restart policy from "no" to on-failure (`3f8900a`)
- Make worktree idempotent - don't restart running services (`68be14e`)
- Fix shared services startup in make worktree (`e15a478`)
- Fix make worktree by removing Jinja2 dependency (`6dafa17`)
- Fix git worktree cleanup to properly stop containers and remove artifacts (`d1c69932`)
- Fix worktree-close to reliably stop containers and sync permissions (`a0bb80e`)

### Monitoring & Grafana
- Add production health check tooling and downtime investigation playbook (`d3b71c9`)
- Add database replication lag monitoring for Redis, Postgres, and Mongo (`7bc1b71`)
- Add replication lag panels to main NewsBlur dashboard (`a41143878`)
- Add Postgres replication slot to prevent WAL gaps on secondary (`448bd83`)
- Add deleted user tracking with Prometheus and Grafana dashboard (`f08e39b`)
- Add premium trial tracking and duration to deleted users dashboard (`c6e9013`)
- Simplify Deleted Users dashboard and add individual user table (`01bcebad`)
- Redesign LLM Costs Grafana dashboard for clarity (`6dd0c97`)
- Add Today's Cost by Model chart to LLM Costs dashboard (`09452bd`)
- Move LLM Costs from separate dashboard to NewsBlur dashboard section (`ceb99d5`)
- Add descriptive labels to LLM Stat panels in Grafana (`d3836d1`)
- Fix LLM costs Prometheus scrape timeout by eliminating scan_iter on 150K keys (`5369acd`)
- Fix LLM Costs panels overlapping Discover Usage in Grafana dashboard (`d3ce662`)
- Add discover usage tracking to Prometheus/Grafana (`36f3d92`)
- Fix Grafana consul alert timing to require continuous 15min downtime (`7fc4f7a`)
- Add Consul service health alert and stack app server graphs (`968ad98`)
- Link Consul health alert to dashboard panel for status indicator (`0c9a1dc`)
- Add legacy alert block to Consul service health panel (`1949bf8`)
- Fix datasource UIDs in alert rules and add Sentry alerts (`5ed17dc`)
- Move Grafana alert files to root alerting directory (`4b40a6e`)
- Convert email contact point from template to static file (`c8ad39e`)
- Fix threshold expression field name in alert rules (`d5a8f2f`)
- Add reduce step to alert rules for multi-series data (`0fd9094`)
- Add reduce step to Sentry alert rules (`3a8aa9a`)
- Remove stacking from all Grafana time series charts (`01bcebad`)
- Fix Grafana panel layout and classifier query for scope-based panels (`8c70dd0`)
- Make ES section panels full-width to prevent Grafana auto-compaction (`f5d559f`)
- Fix Grafana dashboard layout and classifier query for scope-based panels (`7bfd477`)
- Preserve historical classifier data in Grafana Feeds panel (`b0e41ec`)
- Fix doubled classifier series in Grafana Feeds panel (`f5641ff`)
- Increase trending charts limit from 5/10 to 20 items (`fde681f`)
- Add Long Reads trending panel to Grafana dashboard (`e2e6a32`)
- Fix Grafana LLM costs datasource and reorganize Trending section (`00fb1e0`)
- Remove per-IP Prometheus gauges to prevent unbounded cardinality (`3d6b19d`)
- Move rate limit panels into main NewsBlur dashboard (`1de010a`)
- Add soft launch mode for IP rate limiting with Prometheus metrics and Grafana dashboard (`7175ea0`)
- Fix LLM costs Prometheus endpoint to use centralized FEATURES list (`884b837`)

### Server & Database
- Fix downtime root causes: integer overflow, duplicate key races, and thundering herd (`1bc7772`)
- Batch analytics cleanup deletes to prevent MongoDB memory exhaustion (`d1e860c`)
- Replace MapReduce with aggregation pipelines for starred story counts (`5596e3f`)
- Handle Elasticsearch connection errors gracefully in search (`72d0747`)
- Handle Elasticsearch ConnectionTimeout in search query methods (`583062e`)
- Fix duplicate key error race condition in archive batch ingest (`f601a0e`)
- Fix imageproxy OOM crashes with tiered cache and memory limit (`15c233a`, `870b1f0`)
- Add Ansible swap role to fix Grafana flapping on metrics server (`c1acb8b`)
- Fix UFW DOCKER-USER rules not being loaded after Ansible runs (`acf7a56`)
- Add 1Password association by serving AASA as JSON and adding Alpha bundle ID (`db14868`)
- Add Android Digital Asset Links for autofill credential sharing (`7955eb2`)
- Add Postgres replication slot to prevent WAL gaps on secondary (`448bd83`)

### CI & Dev Tools
- Fix CI teardown failure by using --keepdb in test runner (`201e0e5`)
- Add retry logic to CI workflow for transient network failures (`58db2cc`)
- Add /commit, /commit-push, and /commit-all slash commands (`fea8efb`)
- Add /commit-update-pr slash command for Claude Code (`b5e9fc8`)
- Add /worktree slash command for Claude Code (`c4d1ea4`)
- Add dev autologin endpoint and Chrome SSL bypass for local development (`3f1fc4a`)
- Add MCP response size limit hook to save large responses to temp files (`21d3592`)
- Configure Chrome DevTools MCP with --isolated flag for worktrees (`b0e8af0`)
- Add Puppeteer-based chrome-devtools skill, replace MCP as default browser testing tool (`923f3962`)
- Remove Chrome DevTools Puppeteer skill in favor of MCP server (`073a42f`)

## Bug Fixes

Standalone bug fixes not associated with a specific feature area.

- Fix saved stories to show actual read/unread status instead of always read (`5a97d05`)
- Fix SVG self-closing tags being mangled in feed content (`1de010a`)
- Fix 'Read the whole story' expander positioning in center/right layouts (`d3354c2`)
- Fix loading bar persisting after stories load, stop premature fleuron flicker (`25c85c6`)
- Keep loading bar visible during fill_out loop to prevent flicker in Focus mode (`ed86f90`)
- Show "Untitled" for stories with no title, content, or permalink (`08323cb`)
- Fix encoding detection in Story view page fetcher (page_importer.py) (`358a850`)
- Fix encoding detection in TEXT view readability fallback (`84bde94`)
- Fix add_feed_limit rendering Python None as string instead of JS null (`9ca1594`)
- Fix crash in push_notification_setup when feed is not in client collection (`87fa34c`)
- Fix AttributeError when searching within starred stories (`fa724b6`)
- Fix MStarredStoryCounts.DoesNotExist in adjust_count race condition (`22281ea`)
- Fix UserSubscription.DoesNotExist in river_stories deferred field access (`943cb3b`)
- Fix TypeError when YouTube feeds receive RFC 5005 archive_page option (`9171d5a`)
- Fix NameError in save_feed_chooser by adding missing approve_all parameter (`552371`)
- Fix TypeError in mark_story_as_unshared when story not found (`fe4d47a`)
- Fix InvalidURL exception for URLs with spaces in query string (`f11554a`)
- Fix KeyError accessing renamed _id fields in archive breakdown results (`1d6f146`)
- Fix AttributeError in sync_redis when feed is None (`40731a7`)
- Fix RSS feed encoding by normalizing header keys to lowercase (`96038509`)
- Fix slow page loads for high-latency connections (`b29275903`)
- Fix Android app making repeated requests for the same feed page (`5363e7b`)
- Fix TweepError for Twitter pages that do not exist (`b8b1f0d`)
- Fix AttributeError for non-existent DAILY_LIMIT_PREMIUM constant (`c28f93e`)
- Fix feed merge bugs causing muted feeds and data loss (`51ce1f5`)
- Improve feed merge and unmute handling (`60ae42e`)
- Add safe single-feed mute/unmute endpoint (`8cb3bfb`)
- Remove briefing feed folder cleanup since only one user had them (`f81bd18`)
- Enable briefing notifications before first generation (`d0b2bf3`)
- Make server indicator dot always green when connected (`f7a52e8`)
- Remove orphan migrator, add iOS unmute support (`b14bec7`)
- Add request deduplication for Android river_stories to prevent duplicate concurrent requests (`353232d`)
- Add NetNewsWire to platform user-agent parser (`985ad4`)
- Use date_modified as fallback for JSON feeds missing date_published (`1974eae`)
- Make relative image URLs absolute by modifying soup elements directly (`a77faf7`)
- Update user agent strings from outdated Safari to modern Chrome/Edge 143 (`eee4ffa`)
- Apply black and isort formatting fixes (`782b343`, `4ddf35d`, `0b2a81`)
- Route Mercury requests to staging domain on staging server (`3ab628`)
- Switch to @jocmp/mercury-parser fork (`cfa2e6b`)
- Add email writing guidelines to CLAUDE.md (`8a98d5c`)
