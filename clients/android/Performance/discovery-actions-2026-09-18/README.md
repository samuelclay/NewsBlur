# Discovery story previews, shared folders, and Try Feed loading

Validated on the existing Samsung Galaxy S22 (SM-S901U1, Android 16). The account session was preserved; no instrumentation APK, subscription changes, commits, or version bumps were made.

The reference was the unstaged `ios-add-discover-sites` worktree: `DiscoverFeedCardView.swift`, `DiscoverSitesViewController.swift`, and the empty Try Feed refresh in `FeedDetailViewController.swift`.

## Behavior

- Tapping a discovery story immediately highlights that row and opens its exact story hash in the native reader. Back returns to the feed titles, then discovery with the selection and scroll position retained.
- Unsubscribed cards place Try on the left, an unlabeled flexible folder picker in the middle, and Add on the right. The gap after Try is larger than the gap before Add. Folder selections are shared across discovery tabs and forms, retain their full nested path, and display only the leaf title.
- Single-feed reading-session queries tolerate absent subscription metadata. Preview stories previously existed in SQLite but an inner join hid them. The new left join does not create a subscription record or change folder, river, social, or saved-story queries.
- A successful empty first Try Feed API response automatically starts one Insta-fetch. The existing status banner says “Insta-fetching stories…”. Polling runs every two seconds with a 60-second limit, uses cancellable HTTP, and rejects responses from stale sessions. Empty or failed fetches end with a tappable retry message. Explicit retry starts a fresh attempt.

## Regression checks

Before the fix, tapping a discovery story stayed in discovery; the card layout check found the old global folder label. The actual production SQL returned 0 of 2 preview stories without a matching feed row. The fixed query returns both stories, with four additional invariants preserving subscription metadata and broader query behavior.

`JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ANDROID_SERIAL=R5CT601C8DA ./gradlew :app:testDebugUnitTest :app:installDebug`

All **626 tests in 136 suites passed**, with no failures, errors, or skipped tests. The debug APK was installed on the Samsung. Tests cover story hash routing, retained selection, failed preview rollback, duplicate taps, shared full folder paths, query selection, refresh polling, malformed responses, offline errors, timeout, stale sessions, retry state, and real HTTP header/body cancellation.

Device helpers:

- `test_action_row.rb <serial> [folder leaf title]` checks actual visible card geometry.
- `test_story_preview.rb <serial> '<visible story title>' --try` checks the exact article, populated Try Feed titles on Back, and retained discovery selection and scroll. Set `STORY_PROOF_DIR` to save screenshots.
- `test_try_feed_session.rb` executes the compiled production SQL/schema against isolated SQLite fixtures. All five checks pass.

The story helper retries fresh UI hierarchy captures during activity transitions and recognizes Compose's selected-button accessibility mapping as `checked=true`. These are harness details, not application changes.

## Physical layout checks

All four palettes were checked: [light](screenshots/light-folder.png), [dark](screenshots/dark-folder.png), [black](screenshots/black-folder.png), and [sepia](screenshots/sepia-folder.png). [Larger text](screenshots/sepia-large-font.png) keeps Try, folder, and Add on the same row.

A [long folder](screenshots/shared-long-folder.png) truncates cleanly and propagates to YouTube and [Reddit](screenshots/shared-reddit.png). A [nested folder selected in Google News](screenshots/shared-nested-google.png) also appears in Popular after [rotation to landscape](screenshots/nested-landscape.png), without a visible folder label. No Add or Subscribe action was invoked.

## Physical story and Insta-fetch checks

The exact second 404 Media story opened in the [native reader](screenshots/opened.png). Back displayed [populated Try Feed titles](screenshots/feed-list.png), and a second Back retained the selected row and scroll in [light](screenshots/light-selected-story.png), [dark](screenshots/dark-selected-story.png), [black](screenshots/black-selected-story.png), and [sepia](screenshots/sepia-selected-story.png). The Try button independently opened the [populated feed list](screenshots/final-try-feed.png).

Sam Ovens returned a real empty API response with an upstream feed exception. Before the change it only showed [No stories to read](screenshots/empty-before.png). The installed build automatically showed [Insta-fetch progress](screenshots/instafetch-frame-progress.png), then a [retryable error](screenshots/instafetch-failed.png) with the loading bar stopped. Tapping the message produced another [visible fetch attempt](screenshots/instafetch-retry-progress.png) and returned to the terminal error without navigating away. Recordings: [automatic fetch](instafetch.mp4), [tap retry](instafetch-retry.mp4). Device proof covers a real upstream failure; successful empty completion and delayed success/polling are covered by automated tests.

AUTO theme, font scale 1.0, portrait rotation, and automatic rotation are restored. The original read preferences are unchanged. The crash buffer is byte-for-byte unchanged from the baseline, and `git diff --check` passes. The phone is left on the populated 404 Media Try Feed list. All changes remain uncommitted.
