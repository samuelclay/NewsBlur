# Onboarding catalog audit, October 2, 2026

All 50 consolidated interests pass: each has five distinct decoded favicons and at least eight eligible feeds. Food & Cooking has 15 feeds. The original catalog returned 59 labels; nine duplicate labels now resolve to their corresponding interests.

Open `category-audit.html` for the actual icons, selected feeds, and recent story titles. `category-audit.png` is a contact sheet of all 250 card icons. `category-audit.json` contains the machine-readable results and rejection counts.

## What was checked

- Fetched the live `/discover/popular_feeds` endpoint for every canonical interest and each of RSS, newsletters, YouTube, Reddit, and podcasts: `limit=20`, `include_stories=true`, `staleness=year`, `exclude_subscribed=false`.
- Ran the same `OnboardingCatalogSelector.swift` used by the app. It requires a valid nonblank raster favicon, at least three English story titles, a story within the last year, and no feed-fetch exception. The first five feeds have distinct rendered icon fingerprints.
- Reviewed selected feed names and the supplied story titles across all 50 interests. Excluded concrete category mistakes, misleading channel mappings, mixed-language releases, duplicate feeds, and unrelated content in formerly topical feeds. Reviewed replacement selections as well.
- Language checks describe the sampled titles, not every historical article or spoken video language. General Discover and direct site search retain their existing multilingual behavior; these rules apply to onboarding interest bundles.

The old cooking label contained broken YouTube entries; the source quota also limited bundles to three feeds when other source types were missing. A URL to the icon endpoint was treated as evidence of an icon even when that endpoint returned the default globe. Source balance can now fill from other working sources.

## Fresh icon loading

The bulk implementation and timings in this section describe the earlier iteration. The progressive icon update below supersedes its whole-catalog batching.

The initial quality fix made every card download five full feed-and-story responses before showing its icons. With only three categories allowed to load concurrently, browsing 50 categories could queue 250 heavy requests. The physical ClayPad screenshot `/tmp/newsblur-icons-slow-before.png` and failing `test_categoryIconsDoNotDownloadStoryPreviews` captured this regression.

Cards now use audited feed identities from `OnboardingIconCatalog.swift` and fetch current image data from the existing `/reader/favicons` endpoint in bounded batches. There are no bundled image bytes or persistent icon cache. Each new import presentation downloads fresh images with the URL cache bypassed. The first pass fetches five candidates per category; a bounded spare pass handles missing or invalid images. Live story previews and quality validation run when a bundle is opened, independently of the card icon requests.

A live bulk probe for all 250 primary category icons returned in 2.81 seconds on the development Mac. On physical ClayPad, the first six category cards all showed five fresh icons in 6.55 seconds on the first opening and 6.22 seconds after closing and reopening. Those UI timings include the menu tap and presentation animation (`/tmp/newsblur-claypad-fresh-icons-and-folder.xcresult`). Both device checks passed, including the title-cased folder field and named Add action. See `claypad-fresh-category-icons.png` and `claypad-bundle-folder.png`.

## Repeating the selector audit

Save the API responses as a JSON dictionary of category names to their raw `feeds` arrays, combining the five source types for each category. Then run from the repository root on macOS:

```sh
swiftc clients/ios/Classes/OnboardingCatalogSelector.swift \
  clients/ios/Tools/OnboardingCatalogAudit/main.swift \
  -o /tmp/newsblur-catalog-audit
/tmp/newsblur-catalog-audit /tmp/newsblur-live-fresh-catalog.json \
  clients/ios/Performance/ftux-2026-10-02/category-audit
```

The command exits with a failure if any interest has fewer than five valid distinct icons. The snapshot used for this audit is `/tmp/newsblur-live-fresh-catalog.json`; it is deliberately not checked in because it contains large embedded images. Counts are evidence from this snapshot, not a guarantee that external feeds never change.

## Verification

- Reproduced the original missing-icon Cooking bundle on physical ClayPad before editing.
- The new single-working-source regression failed before the selection fix.
- All 17 hosted onboarding tests passed, covering fresh bulk icons, coalescing, missing-image replacements, error retry, quality filtering, subscription queueing, loading, OPML, and dismissal. The previously failing icon-speed regression now passes (`/tmp/newsblur-icons-speed-after.xcresult`).
- Both onboarding UI tests passed, including all four themes and closing/reopening during background work.
- The bundle redesign's loading/Done and four-theme cases passed in `/tmp/newsblur-bundle-redesign.xcresult`; the edited-folder, empty-selection, and singular-count case passed after correcting its test scroll in `/tmp/newsblur-bundle-folder-final.xcresult`. Seven `bundle-redesign-*.png` screenshots were exported and visually checked.
- Physical NB Alpha tests verified Cooking has five icons and at least five feeds with visible story previews, plus early dismissal and reopening of the import sheet. No subscriptions were added by these checks.

All implementation and audit changes remain unstaged in the `iOS-FTUX` worktree. No server deployment or production catalog mutation was performed.

## Progressive previews and batch subscriptions

The bundle preview previously awaited five source requests in sequence before publishing any cards. One live RSS response alone took 10.09 seconds and contained 1.20 MB. The gated regression `test_bundleSourcesStartTogetherAndPreserveChoicesAsResultsArrive` failed on that implementation because only the first request started.

The five sources now start concurrently. Each completed source contributes validated cards immediately; later results preserve the visible card order, deselections, and edited folder name. Switching interests cannot publish stale results into the new sheet. Physical ClayPad showed the first selectable Economics feeds in 3.61 seconds, including the tap and presentation animation. Both live Cooking and Economics checks passed (`/tmp/newsblur-claypad-progressive-bundles.xcresult`), without adding subscriptions. See `claypad-economics-progressive.png`.

Background subscriptions no longer add progress labels to a bundle sheet. Its only loading indicator describes the remaining feed choices. The completion page retains its first-feed-refresh indicator. The underlying reader notifier is suppressed while setup is presented and restored on dismissal if work remains. Its position now uses the feed column bounds and transform-independent geometry, fixing the leftward offset during repeated hide/show transitions.

The authenticated `/reader/add_feeds` endpoint accepts up to 100 known feed IDs and a destination folder in one request. It preserves existing folder contents and placements, reuses the destination on retries, reports per-feed failures, and skips URL discovery and synchronous feed fetching. The client probes support before sending a batch. Older servers retain the existing individual-add path; ambiguous batch failures never trigger duplicate fallback requests.

- All 24 hosted tests passed in `/tmp/newsblur-bundle-progressive-final.xcresult`, including progressive loading, edit preservation, cancellation, batch retries/fallback, and notifier geometry.
- All 25 backend tests passed in `/tmp/newsblur-batch-add-green.log`, covering the new endpoint and existing folder-path behavior.
- Progressive editing, instant Done, and completion-to-reader loading UI cases passed in `/tmp/newsblur-bundle-progressive-ui-final.xcresult`. Its fourth case initially counted duplicate accessibility nodes for one SwiftUI spinner; after correcting that assertion, the quiet-background case passed separately in `/tmp/newsblur-quiet-bundle-green.xcresult`. Screenshots `quiet-background-bundle-phone.png`, `progressive-editable-bundle-phone.png`, `notifier-right-aligned-phone.png`, and `completion-single-spinner-phone.png` were exported and visually checked.
- The final NB Alpha device build succeeded and was installed on ClayPad. The backend endpoint is not deployed; production batch subscriptions require a web deployment.

## Category loading and import layout

The initial catalog now shows one centered, softly tinted loading panel with a thin rotating ring. Reduce Motion keeps the ring still. No bundle cards appear before the category list arrives. The OPML action sits inside its own rounded panel, with an import icon and clearer copy. The heading reads “Explore interests,” shows the loaded count, and shares a row with the search field. Focusing search expands its available width.

The delayed-catalog UI check passed across light, sepia, medium, and dark in `/tmp/newsblur-category-redesign.xcresult`. It verifies there is no premature mixed bundle, the search and heading align, and the cards replace loading when the response arrives. Eight `onboarding-catalog-*.png` screenshots capture both states. The live Cooking check also passed on physical ClayPad in `/tmp/newsblur-claypad-category-redesign.xcresult`; `claypad-import-category-header.png` shows the new import panel and expanded search. NB Alpha was installed and relaunched; changes remain unstaged and uncommitted.

## Progressive icons and explicit dismissal

Visible category cards now request their own icons individually, sharing identical feed requests within this presentation and limiting concurrent downloads to eight. Each valid response is appended immediately, with a short fade and scale transition; pending slots keep their placeholders. There is no whole-catalog completion barrier or persistent cache. Missing icons request audited spares, and retries preserve icons already displayed. Reduce Motion disables the transition.

The setup presentation and nested bundle sheet reject swipe-down dismissal; their X and Done controls remain available. The heading retains “Explore interests” and now says “50 categories to choose from.”

All 25 hosted onboarding tests passed in `/tmp/newsblur-progressive-icons.xcresult`, including a gated response test that proves the first icon is published with four requests still pending. The live ClayPad test passed in `/tmp/newsblur-claypad-icon-stream-retry.xcresult`, including a downward drag followed by explicit close/reopen. Its first run encountered an unreadable catalog response; the successful retry required no production code change. `claypad-progressive-icons-and-swipe.png` shows independently filling card rows and the category count. No commits, staging, or deployments were performed.

The focused UI test also passed in `/tmp/newsblur-icons-progress-phone.xcresult`: one icon appears before the remaining four, then all five appear, and dragging the nested bundle leaves it open until Done is tapped. `category-first-icon-phone.png` and `category-five-icons-phone.png` capture the transition. An earlier fixture delayed every icon request and exceeded the final-count timeout; the final fixture holds only the four icons whose progressive arrival is under test. An iPad simulator retry stalled before executing and was stopped; the existing iPhone simulator completed the final check.

## Whole-card bundle selection

`DiscoverFeedCardView.swift` now uses one button for the entire selectable bundle card, including its header, story titles, images, whitespace, and inclusion row. Deselection fades the whole card to 50% opacity; another tap restores it. Reduce Motion disables the fade animation. Already added or queued cards retain their existing status, and ordinary Discover cards retain their preview and Add actions.

The four-theme UI check passed in `/tmp/newsblur-whole-card-final.xcresult`, verifying taps at the header, story text, image edge, and footer, the matching Add count, and no selection change while scrolling. Eight `onboarding-whole-card-*.png` screenshots record included and excluded states. Earlier test attempts targeted an offscreen feed or its footer below the fixed Add bar; the final test uses the visible card and scrolls the footer into view.

The device build succeeded, and NB Alpha was installed and launched on ClayPad. The physical tap check did not execute because iPadOS required Touch ID for “Enable UI Automation”; `/tmp/newsblur-claypad-whole-card-state.png` records the prompt. Device interaction verification remains pending that authorization. Changes remain unstaged and uncommitted.

## Return to interests and quiet completion

The Add action now queues the selected feeds and immediately dismisses only the nested chooser, retaining the parent category scroll position. Page 2 no longer shows “Loading your feeds”; subscription requests and the final refresh still run in the background. This supersedes the earlier completion-page spinner design. Cooking remains backed by the existing audited `food & cooking` catalog key, but its visible title and default folder are now “Cooking & Food,” sorted under C.

The device build succeeded and NB Alpha was installed and launched on ClayPad. All 25 hosted onboarding checks passed, as did the UI check for opening another category while subscriptions are queued. The first completion UI run verified automatic dismissal, retained scroll position, and quiet page 2; its later reader-spinner assertion assumed the feed sidebar was visible. The screenshot showed the iPad had opened the story pane with the sidebar hidden. The final test opens the sidebar before checking its notifier, and the slow-addition fixture lasts eight seconds to keep work pending through navigation. No staging, commits, or server deployments were performed.

The corrected completion UI test passed in `/tmp/newsblur-quiet-completion-final.xcresult`, including the reader notifier clearing after the queued work finishes. `onboarding-quiet-completion.png` and `onboarding-returned-to-interests.png` show the requested navigation and quiet completion state.

## Category selection feedback

Category cards now retain the URLs selected through their Add action. A teal tint, outline, and checkmark count appear immediately on return to Explore interests. The count says “feeds selected” while requests remain queued and “feeds added” when they succeed. Failed additions do not count as added; retries update the same category, and reopening it still allows choosing skipped feeds. Cards reserve the same status area so their heights remain consistent across the grid. Colors adapt to all four themes.

The category count/retry check and both UI flows passed in `/tmp/newsblur-category-added.xcresult`. The UI run checks immediate selected counts with delayed additions, quiet completion, and successful added counts across light, sepia, medium, and dark. Four `onboarding-category-added-*.png` screenshots record the highlighted cards. The latest NB Alpha device build was installed and launched on ClayPad; the interaction checks in this run used the existing iPad simulator.

## Completion page recap

The final page now has a centered confirmation mark and a recap of this setup's selected feeds, grouped under their actual destination folders. The recap includes favicon tiles, names, and counts, retains renamed and nested folders, and excludes failed additions. OPML parsing preserves folder paths for the recap, and imported icons use the existing reader refresh plus the bounded icon loader. No extra feed-list request or loading spinner is introduced. An empty selection has a concise ready state instead of a blank recap.

“Back to feeds” and the closing good-luck message are removed. The community card has a forum icon and local avatars with X badges for `@samuelclay on X` and `@NewsBlur on X`. The Samuel portrait comes from `media/img/static/Samuel Clay sq.jpg`, the NewsBlur avatar uses the existing logo, and the X mark comes from the repository's Remix icon set.

All 25 hosted onboarding tests passed, including the nested OPML receipt and failed-addition recap checks. The iPhone empty-state test passed in `/tmp/newsblur-completion-phone.xcresult`; both phone screenshots are saved here. The initial iPad checks found a test query relying on a folder identifier SwiftUI did not expose. Screenshots confirmed that the renamed folder and all icons rendered correctly; the final check queries the visible folder name instead. The latest NB Alpha build was installed and launched on ClayPad. Interaction checks for this redesign use the existing simulators; physical interaction verification was not repeated.

The final iPad recap test passed across all four themes in `/tmp/newsblur-completion-recap-verified.xcresult`. It verifies a renamed destination, the removed controls, both X links, quiet background work, and Start reading. Four `onboarding-recap-*.png` screenshots capture the verified page. No changes were staged or committed.

## Final iPad layout and commit verification

The later instruction authorizes committing and pushing all task changes, superseding the earlier unstaged-work notes above. The batch endpoint and narrow Auto layout were committed and pushed separately; the remaining onboarding changes and evidence follow them.

Auto layouts below 1100pt now overlay the feed list, preserving the title and article widths. Selecting a feed closes the overlay. The regression first measured an article shrinking from 419pt to 99pt; the fixed UI test preserves 419pt and verifies dismissal. All 131 Swift package tests pass, including explicit layout preferences and wide layouts. `ipad-auto-sidebar-hidden.png` and `ipad-auto-sidebar-overlay.png` show the fixed transition.

iPad sync status now shares the account-name row, using the navigation title's available width and leaving counts and sidebar controls clear. Long usernames and narrow headers adapt; iPhone keeps its existing presentation. All 26 hosted onboarding tests pass, including compact geometry and restoration of the name after sync ends. The first fixed UI run queried the obscured reader Sidebar button rather than the overlay's visible button. The final test selects the visible control, checks nonoverlapping frames, and taps it to close the sidebar; it passes in `/tmp/newsblur-sync-header-verified.xcresult`. `ipad-compact-sync-header.png` shows the new placement.

The combined social-auth and batch-subscription backend preflight passes all 25 tests. NB Alpha built successfully and was installed and launched on ClayPad. No server deployment or App Store submission was performed.
