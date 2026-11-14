# Android Add + Discover Sites

Branch: `android-add-discover-sites`, based on `android-scroll-performance` at `36bb712a8`.
Reference: `ios-add-discover-sites` discovery models, view model, and source tabs; web `media/js/newsblur/views/add_site_view.js` and `apps/discover/views.py`.

The main feed-list plus button, Add menu, and existing feed-search intents open a native Compose discovery screen. Quick Add remains available from the toolbar, and external share intents retain the existing Add Site sheet.

## Feature coverage

- Search with debounced autocomplete, trending feeds, and direct URL addition.
- Popular, YouTube, Reddit, newsletters, and podcasts: category/subcategory browsing, newsletter platform filters, pagination, and source-specific search. Catalog/source searches merge without losing usable results when one source fails.
- Feed cards support grid/list layouts, story headlines in list mode, existing-subscription indicators, and the existing unsubscribed feed preview. Catalog IDs are resolved to NewsBlur feed IDs before preview.
- Google News includes the iOS catalog of 47 categories, topic selection, custom searches, and language selection.
- Web Feed includes analysis, polling, variant/story previews, refinement hints, title editing, retention, mark-unread behavior, RSS detection, and subscription.
- Folder selection uses existing Android folder identities; quick-created folders refresh after feed/folder sync. Ambiguous web-feed folder names are rejected because that backend accepts only a leaf folder name.
- Colors use `ReaderSheetPalette`, including light, dark, black, and sepia. Landscape uses adaptive columns; forms scroll with the keyboard and retain state through activity recreation.

## Automated validation

On the final implementation build (`2c075817d`):

```
env JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :app:testDebugUnitTest \
  --tests 'com.newsblur.discover.*' --tests 'com.newsblur.addsite.*' :app:assembleDebug
```

28 tests passed (18 new discovery tests and 10 existing Add Site tests). Coverage includes stale searches, debounce/clear, source fallback and deduplication, pagination, saved state, duplicate-submit prevention, preview ID resolution, Google News, newsletter conversion, RSS detection, analysis variants, timeout/error recovery, and preserving the analyzed URL when the input changes.

The shared iOS backend polling changes were copied into `apps/webfeed`. All four `Test_WebFeedStatus` tests passed in the worktree Docker container. The worktree Celery worker was restarted after the task change.

## Live server boundaries

Production `/webfeed/status` returned HTTP 404 during verification. Complete live web-feed creation requires deployment of the included shared backend change to both web and Celery servers. No production deployment was performed.

The live Reddit source-search endpoint returned `code=-1`; curated Reddit results remained usable. YouTube and podcast source searches returned 10 and 16 results respectively in the verification queries.

The first Veritasium source preview opened the unsubscribed reader correctly but had no stories cached yet. This is not evidence of loaded story content for that particular feed.

## Device validation

Used the existing Samsung SM-S901U1 running Android 16 over USB and preserved its login. The final debug build remains installed. No instrumentation APK was installed.

The screenshot directory contains the full 8 tabs × 4 themes × 2 orientations matrix. PNG dimensions were checked to distinguish actual portrait (1080×2340) from landscape (2340×1080) captures. Additional screenshots cover source searches, previews, two-column landscape cards, folder refresh, and subscriptions. Some initial light-theme captures show loading states; loaded source cards were separately checked and captured.

- Live YouTube search (`veritasium`) retained its query/results through rotation and returned to discovery after preview.
- Live Reddit search (`space`) retained curated matches despite the upstream source error.
- Newsletter URL conversion (`https://www.platformer.news`) produced its feed URL.
- Podcast search (`radiolab`) merged catalog and live source results.
- Quick Add created `Android Discovery Test 20260916` and `Android Discovery Sync 20260916`. A device check exposed the wrong sync notification; discovery now observes `UPDATE_METADATA`, and the second new folder appeared in the picker without reopening the screen.
- Golden Hill Software (feed 6225909) and a unique Google News query (feed 10313734) were added through the discovery UI. A separate server read verified both IDs inside the selected temporary folder.
- Opening the added Golden Hill Software feed displayed the normal reader with loaded stories and no unsubscribed banner (`subscribed-feed-open.png`).
- Google News retained Anime & Manga, Anime Awards, and Français through reverse-landscape rotation and switching away to Web Feed and back.
- With Wi-Fi and mobile data disabled, search displayed its error and Retry action. After reconnecting, Retry loaded results (`offline-search.png`, `offline-recovered.png`).
- Both temporary folders and both test subscriptions were removed, with a separate server read verifying cleanup. The original automatic theme, automatic rotation, portrait rotation preference, and default animation setting were restored; Wi-Fi and mobile data are enabled. The device crash log was empty at the end of verification.

The 64-image theme/orientation matrix was captured before the final interaction fixes; those fixes were then verified on the final build with the supplemental screenshots. The Web Feed analysis screenshot is a loading state, followed by the server error in `web-feed-server-result.png`; it is not a successful live creation claim.

## Push note

The repository's configured unqualified `git push` also advanced existing local branches on the first implementation push: `main` from `9525d815e` to `473717444` (two forum-triage records), and `ios-scroll-performance` from `9d7f36de7` to `b597772e1` (three existing iOS commits). The attempted `ios-add-discover-sites` push was rejected. No changes to those branches were authored in this task. Every subsequent push explicitly targeted `android-add-discover-sites`.
