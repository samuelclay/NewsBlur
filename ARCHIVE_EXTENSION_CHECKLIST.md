# Archive Extension Implementation Checklist

Track progress on the Archive Extension feature. Check off items as they are completed.

## Phase 1: Backend Infrastructure

### Django App Setup
- [x] Create `apps/archive_extension/` directory structure
- [x] Add `archive_extension` to `INSTALLED_APPS`
- [x] Configure `MONGO_ANALYTICS_DB` in settings (already configured as `nbanalytics`)
- [x] Create URL routing in `newsblur_web/urls.py`

### Data Model
- [x] Define `MArchivedStory` MongoEngine model
- [x] Set up indexes for efficient queries
- [x] Add migration/initialization for analytics MongoDB collection (auto-created by MongoDB)
- [ ] Test model CRUD operations

### API Endpoints
- [x] `POST /api/archive/ingest` - Single page ingestion
- [x] `POST /api/archive/batch_ingest` - Batch upload
- [x] `GET /api/archive/list` - List with filters (date, domain, category)
- [x] `GET /api/archive/search` - Full-text search (Elasticsearch integration added)
- [x] `GET /api/archive/categories` - Category breakdown
- [x] `POST /api/archive/delete` - Soft delete
- [x] `GET/POST /api/archive/blocklist` - Manage blocklist
- [x] `GET /api/archive/stats` - Usage statistics
- [x] `GET /api/archive/export` - Export data (JSON/CSV)

### Story Matching
- [x] URL normalization (strip tracking params, canonicalize)
- [x] Match against `MStory.story_permalink` in user's feeds
- [x] Content length comparison logic
- [x] Mark matched stories as read in Redis
- [ ] Unit tests for matching edge cases

### Search & Indexing
- [x] Create Elasticsearch index mapping for archives
- [x] Implement archive indexing on ingest
- [ ] Add vector embeddings using existing method
- [ ] Test search queries

### Background Tasks
- [x] `process_archive_batch` Celery task
- [x] `categorize_archives` Celery task (AI categorization)
- [x] `index_archive_for_search` Celery task
- [x] Configure task queues (added to CELERY_IMPORTS)

### Authentication
- [x] Add `archive` OAuth scope
- [x] Implement token validation for extension (via ajax_login_required)
- [x] Add Premium Archive tier check

---

## Phase 2: Archive Assistant

### Django App Setup
- [x] Create `apps/archive_assistant/` directory structure
- [x] Add URL routing
- [x] Define models (`MArchiveQuery`, `MArchiveConversation`, `MArchiveAssistantUsage`)

### Claude Agent SDK Integration
- [x] Define archive search tool
- [x] Define get content tool
- [x] Define get categories tool
- [x] Implement tool execution handler
- [x] Add streaming response via Redis PubSub (polling-based for now)

### API Endpoints
- [x] `POST /archive-assistant/query` - Submit query
- [x] `GET /archive-assistant/conversation/:id` - Conversation with queries
- [x] `GET /archive-assistant/conversations` - List conversations
- [x] `POST /archive-assistant/conversation/:id/delete` - Delete conversation
- [x] `GET /archive-assistant/suggestions` - Suggested questions
- [x] `GET /archive-assistant/usage` - Usage statistics

### System Prompts
- [x] Write archive assistant system prompt
- [ ] Test prompt effectiveness with various query types

### Node.js WebSocket Handler
- [x] Add Archive Assistant events to `node/archive_assistant.js`
- [x] Test streaming responses

---

## Phase 3: NewsBlur Web UI

### Archive Folder (Sidebar)
- [x] Add Archive folder UI in `templates/reader/feeds_skeleton.xhtml`
- [x] Handle Archive folder click in `reader/reader.js`
- [x] Add Archive icon to `media/img/icons/nouns/archive.svg`
- [x] Add AI brain icon to `media/img/icons/nouns/ai-brain.svg`
- [x] Add click handler in `views/sidebar.js`
- [x] Add router route for `/archive`
- [x] Add favicon for archive in `jquery.newsblur.js`

### Archive View (Combined Browser + Assistant)
- [x] Create `views/archive_view.js` with tabs
- [x] Implement chat interface for Archive Assistant
- [x] Add filters (category, domain) in browser tab
- [x] Add pagination with load more
- [x] Add suggested questions
- [x] Add CSS in `reader.css`
- [x] Add dark mode support

### Settings Page
- [x] Add Blocklist tab to archive view
- [x] Blocklist management UI (add/remove blocked domains, patterns, allowed domains)
- [ ] Export button (deferred)
- [x] Extension download links (in Archive view UI, URLs need updating when published)

---

## Phase 4: Browser Extension (WebExtensions)

### Project Setup
- [x] Create `clients/browser-extension/` directory structure
- [x] Set up build system (shell scripts + npm scripts)
- [x] Configure Manifest V3
- [x] Add Firefox manifest overrides
- [x] Create content extraction using Readability-inspired approach

### Background Service Worker
- [x] Implement page visit tracking (`tabs.onUpdated`)
- [x] Implement navigation detection (`webNavigation.onBeforeNavigate`)
- [x] Implement tab close handling (`tabs.onRemoved`)
- [x] Filter quick bounces (< 5 seconds)

### Content Extraction
- [x] Implement `detector.js` content script
- [x] Simple Readability-style parsing
- [x] Handle extraction failures gracefully
- [x] Message passing between content script and background

### Blocklist
- [x] Implement default blocklist (domains + patterns) - in constants.js
- [x] Add user blocklist from storage
- [x] Check URLs against blocklist efficiently
- [x] Handle incognito mode detection

### Sync
- [x] Implement debounced sync (5-second delay)
- [x] Implement batch upload (up to 10 items)
- [x] Handle network failures with retry
- [x] Store pending items in local storage

### OAuth Authentication
- [x] Implement `chrome.identity.launchWebAuthFlow`
- [x] Store token in `chrome.storage.local`
- [x] Handle token refresh/expiration
- [x] Show login prompt when not authenticated

### Popup UI
- [x] Create `popup.html` layout
- [x] Implement Save button (from bookmarklet)
- [x] Implement Share button (from bookmarklet)
- [x] Implement Subscribe button (from bookmarklet)
- [x] Show archive status of current page
- [x] Show recent archives with:
  - [x] Rich preview (favicon, title, excerpt)
  - [x] AI category pills
  - [x] Timestamp
  - [x] Recent list view
- [x] Add search link to NewsBlur
- [x] Settings link

### Options Page
- [x] Create `options.html` layout
- [x] Blocklist management (add/remove domains)
- [x] Account connection status
- [x] Clear local data option

### Build & Package
- [x] Build script for Chrome
- [x] Build script for Firefox
- [x] Build script for Edge (same as Chrome)
- [ ] Test on each browser

---

## Phase 5: Safari Extension

### macOS App Wrapper
- [x] Create Xcode project
- [x] Create `AppDelegate.swift`
- [x] Create `ViewController.swift` (extension status UI)
- [x] Create Main.storyboard
- [x] Create Assets.xcassets structure

### Safari Web Extension
- [x] Create Safari manifest.json
- [x] Implement `SafariWebExtensionHandler.swift`
- [x] Configure entitlements (App Groups, network client)
- [x] Create build script to copy WebExtension resources
- [ ] Test on Safari

### Distribution
- [ ] Configure App Store Connect
- [ ] Notarization setup
- [ ] Submit for review

---

## Phase 6: Testing & QA

### Unit Tests
- [x] API endpoint tests (basic auth checks)
- [x] Story matching tests (URL normalization, matching)
- [x] Blocklist pattern tests (domains, patterns)
- [ ] Content extraction tests

### Integration Tests
- [ ] Full ingest flow test
- [ ] Archive Assistant query test
- [ ] OAuth flow test
- [ ] Extension-to-backend sync test

### Browser Testing
- [x] Chrome manual testing (local dev - Archive folder, API endpoints, tabs)
- [ ] Firefox manual testing
- [ ] Edge manual testing
- [ ] Safari manual testing
- [ ] Test with various site types

### Performance Testing
- [ ] Batch ingestion load test
- [ ] Elasticsearch query performance
- [ ] Extension memory usage

### Security Review
- [ ] OAuth implementation review
- [ ] Data isolation between users
- [ ] Blocklist effectiveness
- [ ] Content script permissions

---

## Phase 7: Launch

### Store Submissions
- [ ] Chrome Web Store submission
- [ ] Firefox Add-ons submission
- [ ] Microsoft Edge Add-ons submission
- [ ] Mac App Store submission (Safari)

### Documentation
- [x] User guide for extension (README.md files)
- [ ] API documentation
- [ ] Privacy policy update

### Monitoring
- [ ] Add metrics endpoint for archive stats
- [ ] Set up alerts for failures
- [ ] Monitor storage growth

---

## Future Enhancements (Post-Launch)

- [ ] iOS app integration (Share Extension + background monitoring)
- [ ] Android app integration
- [ ] Improved AI categorization
- [ ] Archive deduplication
- [ ] Collaborative archives (share with friends)
- [ ] Archive annotations/highlights

---

## Files Created

### Backend (`apps/archive_extension/`)
- `__init__.py` - App initialization
- `models.py` - MArchivedStory, MArchiveUserSettings models
- `views.py` - All API endpoints
- `urls.py` - URL routing for /api/archive/*
- `tasks.py` - Celery tasks for categorization and indexing
- `matching.py` - Story matching logic
- `blocklist.py` - Default blocklist domains and patterns
- `search.py` - Elasticsearch integration for full-text search
- `tests.py` - Unit tests for URL normalization, blocklist, matching

### Archive Assistant (`apps/archive_assistant/`)
- `__init__.py` - App initialization
- `models.py` - MArchiveConversation, MArchiveQuery, MArchiveAssistantUsage models
- `views.py` - API endpoints for chat, suggestions, usage
- `urls.py` - URL routing for /archive-assistant/*
- `tasks.py` - Celery task for async query processing with Claude
- `prompts.py` - System prompts and suggested questions
- `tools.py` - Claude tool definitions and execution handlers
- `tests.py` - Unit tests for tools, prompts, API endpoints

### Frontend
- `media/js/newsblur/views/archive_view.js` - Archive browser + assistant view
- `media/img/icons/nouns/archive.svg` - Archive folder icon
- `media/img/icons/nouns/ai-brain.svg` - Archive Assistant icon

### Browser Extension (`clients/browser-extension/`)
- `manifest.json` - Chrome/Edge Manifest V3
- `manifest.firefox.json` - Firefox Manifest V2
- `package.json` - npm scripts
- `README.md` - Documentation
- `build/build.sh` - Build script
- `icons/` - Extension icons (16, 32, 48, 128)
- `_locales/en/messages.json` - i18n
- `src/shared/constants.js` - Constants, blocklist, patterns
- `src/shared/utils.js` - Utility functions
- `src/lib/api.js` - NewsBlur API client
- `src/lib/storage.js` - Chrome storage wrapper
- `src/background/service-worker.js` - Background script
- `src/content/detector.js` - Content extraction
- `src/popup/popup.html` - Popup UI
- `src/popup/popup.css` - Popup styles
- `src/popup/popup.js` - Popup logic
- `src/options/options.html` - Options UI
- `src/options/options.css` - Options styles
- `src/options/options.js` - Options logic

### Safari Extension (`clients/safari-extension/`)
- `NewsBlur Archive.xcodeproj/project.pbxproj` - Xcode project
- `NewsBlur Archive/NewsBlur Archive/AppDelegate.swift` - App delegate
- `NewsBlur Archive/NewsBlur Archive/ViewController.swift` - View controller
- `NewsBlur Archive/NewsBlur Archive/Main.storyboard` - UI layout
- `NewsBlur Archive/NewsBlur Archive/Info.plist` - App config
- `NewsBlur Archive/NewsBlur Archive/NewsBlur_Archive.entitlements` - Entitlements
- `NewsBlur Archive/NewsBlur Archive/Assets.xcassets/` - Asset catalogs
- `NewsBlur Archive/NewsBlur Archive Extension/SafariWebExtensionHandler.swift` - Native messaging
- `NewsBlur Archive/NewsBlur Archive Extension/Info.plist` - Extension config
- `NewsBlur Archive/NewsBlur Archive Extension/NewsBlur_Archive_Extension.entitlements` - Entitlements
- `NewsBlur Archive/NewsBlur Archive Extension/Resources/manifest.json` - Safari manifest
- `build.sh` - Build script
- `README.md` - Documentation

### Configuration Changes
- `newsblur_web/urls.py` - Added archive_extension and archive_assistant URL includes
- `newsblur_web/settings.py` - Added to INSTALLED_APPS, CELERY_IMPORTS, OAUTH2_PROVIDER scopes
- `media/js/newsblur/views/sidebar.js` - Added Archive click handler
- `media/js/newsblur/views/feed_list_view.js` - Added Archive folder display logic for premium archive users
- `media/js/newsblur/common/router.js` - Added /archive route
- `media/js/newsblur/reader/reader.js` - Added open_archive function, selectors, cleanup
- `media/js/vendor/jquery.newsblur.js` - Added archive favicon type
- `media/css/reader/reader.css` - Added Archive view styles
- `templates/reader/feeds_skeleton.xhtml` - Added Archive folder header
