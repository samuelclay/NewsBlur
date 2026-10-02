# Mac Catalyst and login follow-up, September 11, 2026

All work remains in `ios-scroll-performance`. The user requested no new commits before 6 p.m. Pacific on September 11. Successful authentication should return to an empty feed list while subscriptions load, with no selected feed, story titles, or article restored from the previous session.

Subsequent notification changes and renewed device/Mac installations are documented in [the notification follow-up](2026-09-11-notification-feed-navigation.md). The validation and installation sections below describe the earlier checkpoint 76.

## Mac build provenance

The reported Mac app process ran from `/Users/sclay/Library/Developer/Xcode/DerivedData/NewsBlur-dnwoengkjrcsjaezlhydxgrfmbhw/Build/Products/Debug-maccatalyst/NB Alpha.app`. Its DerivedData `info.plist` identifies the main checkout's Xcode project, not this worktree. Main did not contain the performance branch's header, preference-selection, unread-count, or article-presentation changes.

The worktree's signed Release Catalyst build succeeds in `/tmp/newsblur-scroll-mac-derived`, using the `NewsBlur Alpha` scheme and the local arm64 Mac destination. Build evidence: `/tmp/newsblur-mac-baseline-build-58.log`.

## Existing fixes on Catalyst

The first Mac runtime check executes the same UIKit controls and story-read code as the iOS regressions. All six preference-menu tests and eight feed-count tests pass. The narrow-header test shows a complete Discover icon and `UNREAD` at 320 points; resizing, wider labels, favicons, Daily Briefing, and search state also pass. The compound-button geometry assertion alone needs a one-display-pixel tolerance because Catalyst lays out the requested 98-point stack at 98.5 points. No production header adjustment is required for these results.

Evidence: `/tmp/newsblur-scroll-evidence/mac-baseline-58.xcresult`, `/tmp/newsblur-mac-baseline-tests-58.log`. Exported images in `/tmp/newsblur-scroll-evidence/mac-baseline-images-58` show the compact header and a retained feed badge repainting from 10 to 9. These are isolated runtime fixtures, not a recording of scrolling the physical Mac account.

A separate path review confirms that Catalyst creates the same `StoryTitlesHeaderBar` and uses its bounds-change relayout callback. The native Mac toolbar contains separate icon actions; it does not replace the Discover/filter pill bar. The shared adaptation therefore requires the worktree build, not a separate Mac implementation.

## Reproduced defects

`FeedDetailObjCViewController.m` ignores the clicked Mac toolbar item when presenting Site Settings and instead uses fixed coordinates. The native toolbar item is already preserved by the responder chain, and UIKit supports using it as the popover source.

Both successful authentication callbacks in `LoginViewController.m` call `reloadFeedsView:YES` before dismissing. That method only starts fetching subscriptions; the selected collection, story rows, article pages, and pending navigation remain populated. Clearing must be specific to successful authentication so normal feed refreshes keep the current reading session.

The Computer Use tool failed to initialize its native pipe, including after a kernel reset. Desktop clicking and fresh full-window capture through that tool are unavailable in this run; runtime test captures are identified separately above.

## Reproductions and Catalyst test setup

The two new Site Settings tests fail in `mac-anchor-red-60.xcresult`: the native toolbar item is missing as the popover source at four window widths, and a moved UIKit button does not become the source view. Both now pass in `mac-article-and-anchor-after-64.xcresult`. The actual clicked toolbar item is forwarded to UIKit's `sourceItem`; view senders retain the existing `sourceView` path.

Seven authentication regressions execute the production login/signup callbacks with synthetic transport and already-rendered story content. Four cases fail on both platforms, with 126 assertions and no unexpected failures: compact login, regular-width login, signup, and an old subscription response arriving after the new response. Rejected credentials, network failure, and ordinary subscription refresh pass. Before results are `authentication-reset-before-r4.xcresult` (simulator) and `mac-auth-red-65.xcresult` (Catalyst). The synthetic account fixtures do not submit real credentials or change the user's account.

The first full Catalyst run executes 326 cases in `mac-full-baseline-59.xcresult`. Its failures identify test-host assumptions: phone-only toolbar geometry, a loopback HTTP server denied by the Mac sandbox, UIKit memory-warning eviction expectations that do not apply on Catalyst, and thumbnail draws without the view traits UIKit normally installs. The original phone inset assertions remain intact through explicit phone fixtures; a separate native Mac case checks zero inset/restoration. Image parity still requires the exact prepared image, color/orientation/scale equality, and byte-identical cell rendering. Keyboard storage now waits for its callback instead of a fixed 50 ms delay.

The local HTTP fixtures require `ENABLE_INCOMING_NETWORK_CONNECTIONS=YES` only while building the Catalyst test host. It is a command-line testing override, not a production entitlement change. With those corrections, all 62 article cases and all eight menu cases pass in `mac-article-and-anchor-after-64.xcresult`. That run also passes image parity; one reverse-scroll test's polling expectation times out despite its final draw recording zero main-thread disk reads and one worker read. The fixture now observes actual memory-cache publication directly.

## Validation checkpoints

The corrected thumbnail fixture passes all 52 cases in `mac-thumbnail-after-66.xcresult`. The full existing Catalyst performance suite then passes 329 tests with zero failures in 91.841 seconds in `mac-performance-full-after-67.xcresult`. This checkpoint includes the native popover anchor fix and preserves the thumbnail pixel-equality assertions. It precedes the authentication implementation; the new authentication cases were explicitly excluded from this checkpoint.

Ten authentication regressions reproduce the stale session on the simulator in `authentication-reset-before-r6.xcresult`, with 173 expected assertion failures and no unexpected failures. They add queued SQLite publication, relaunch before the new subscription response, and the prior offline timer to the original seven cases. The first implementation passes the session assertions; strengthened header-label assertions then reproduce 64 remaining failures in `authentication-header-before.xcresult`.

After clearing the visible header and rejecting old avatar completions, all ten authentication cases and 61 adjacent first-page cache/loading and story-list cases pass in `authentication-reset-final-after.xcresult` (71 total, zero failures, 48.019 seconds). Immediate callback screenshots can retain the last committed UIKit frame even after synchronous state assertions pass. Final visual verification must inspect a subsequent displayed frame while the new subscription response remains held.

The same ten authentication cases pass on Catalyst in `mac-auth-after-68.xcresult` (zero failures, 7.976 seconds). Subsequent checks add the empty-account response and delayed count-refresh cases.

The expanded 15-case suite reproduces nine expected assertions in `authentication-refresh-before.xcresult`: two stale unread-count response paths, a stale failure, queued UI/offline publication, and the missing header when a new account has no subscriptions. Current-account refresh still passes. A delayed old response changes a new account's count from 7 to 99 before the guard is added.

The subsequent displayed frame, with the new subscription GET still held, confirms that old content is gone: `authentication-refresh-before-attachments/22A969FB-CD53-42D5-B610-8F1D60AA93F7.png`. It also exposes the finished-list action in an unselected empty title pane; the final reset uses the existing select-a-feed placeholder so no mark-all action remains there.

The empty-title regression fails with six expected assertions in `authentication-placeholder-before.xcresult`. After the final fixes, all 15 authentication cases pass in `authentication-final-after.xcresult` (zero failures, 18.341 seconds). The worker calculates count/visibility changes from immutable inputs and applies them on main only if they still belong to the same account; current-account refresh and failure handling are preserved. An authenticated account with zero subscriptions rebuilds its header before onboarding.

The combined simulator login/loading/cache/list checkpoint passes 76 cases in 54.796 seconds. Final displayed-frame evidence is `authentication-final-after-attachments/3A0D226D-626B-4D0E-BE6E-A7F6C6375C33.png`: both story panes show their normal selection prompts, with no earlier content or mark-all footer. The regular fixture is three columns fitted to the phone's bounds, so its prompt truncation is a fixture limitation.

The full iOS suite passes all 341 tests with zero failures in 123.756 seconds in `ios-final-full-70.xcresult`. A concurrent full Catalyst run executes 344 cases and records seven assertion failures in existing favicon, retained-article, and text-prefetch fixtures (`mac-final-full-69.xcresult`). The favicon fixture writes over a mapped PNG non-atomically, unlike production PINDiskCache; its replacement write now uses atomic file replacement. The retained-article fixture now loads a real 4,000-point HTML document before setting offset 321 instead of assigning a size to an unloaded WKWebView. Authentication fixture teardown advances its private generation before restoring preferences, preventing late fixture responses from rewriting them.

A focused Catalyst run covering authentication, favicons, the retained article, and text layout passes all 32 cases (`mac-fixture-check-71.xcresult`, zero failures, 19.755 seconds). The text-prefetch failure did not recur; diagnostic context was added with all original worker-count, main-thread-work, and pixel assertions retained. No production prefetch change was made for this intermittent result.

The next full Catalyst run (`mac-final-full-72.xcresult`) passes the favicon and real-document article cases and isolates the remaining four assertions to the two native text-prefetch tests. Entry diagnostics show valid rows/table geometry and an absent preview-cache entry. Over the five-second wait, the completion/prefetch cycle repeats normalization 75,785 times without retaining the preview or preparing a layout. This is a real no-progress retry loop when the optional cache does not retain a value. System memory was 53% free when checked afterward, so that evidence does not establish system memory pressure as the reason for the miss. The warm fixture also omitted the production preview cache's 512-entry limit; it now matches that configuration, with separate deterministic rejecting-cache regressions for bounded recovery.

`mac-preview-rejection-before-73.xcresult` reproduces the loop deterministically with a preview cache that rejects writes. Native prefetch performs four normalizations during the short settling interval and produces zero layouts, instead of one normalization and one layout. Those two assertions fail; the seven unchanged text-performance/pixel tests pass with the warm fixture configured like production. These are operation-count observations in a synthetic cache-rejection scenario, not feed-scrolling FPS measurements.

## Authentication implementation

Successful login and signup now call one account-reset entry point before dismissing the form. It clears feed rows, username/counts/avatar, selected stories, article pages, search and pending navigation, SwiftUI story caches, and account-owned image generations. A failed login or ordinary refresh keeps the current reading session.

The reset removes the persisted active-account selector until the authenticated subscription response identifies the new account. Existing account-owned SQLite rows and pending read/save journals remain intact. Generation checks reject old subscription, offline, avatar, and deferred story publications. Offline story queries capture their feed/page/filter inputs before leaving the main thread and apply their read hashes only if that query still belongs to the current selection.

## Preview cache recovery

`FeedDetailObjCViewController.m` now passes each completed worker preview directly into layout preparation. An optional cache rejecting the write no longer forces normalization to repeat. This temporary map contains bounded normalized strings, exists only during synchronous layout preparation, and is released before completion returns. Cell drawing, text metrics, images, and spacing remain unchanged.

Continuation work contains only remaining byte-budget rows, newly requested rows, canceled work, or changed story inputs. Completed rows are removed from that set even when the cache rejects them. The existing 24-row and 4 MiB source bounds remain in place.

Three deterministic regressions cover rejected writes, changed content plus a newly requested row, and byte-limited continuation. The original rejection reproducer now performs one worker normalization and prepares one layout, with zero main-thread normalization. The changed-input case performs three normalizations and prepares the two current layouts; the four-row byte-limited case performs four normalizations and prepares four layouts without revisiting completed rows.

## Final validation

The complete Catalyst suite passes **347 tests, zero failures, in 106.727 seconds** in `mac-final-full-74.xcresult`, logged at `/tmp/newsblur-mac-final-full-74.log`. It includes all 15 authentication cases, all eight eviction/recovery cases, menu anchoring and selection, feed count publication, adaptive headers, article positioning, and the existing 1,080-case text pixel/layout matrix. This is a Release runtime test suite, not a live-account Mac scrolling FPS recording.

The complete iOS suite on the existing iPhone 17e simulator passes **344 tests, zero failures, in 129.212 seconds** in `ios-final-full-75.xcresult`, logged at `/tmp/newsblur-ios-final-full-75.log`. This run includes the final preview retry implementation and all authentication changes. `git diff --check` also passes. No source files were changed after these two final runs.

## Release builds and installations

Normal signed Release builds succeed for Catalyst and physical iOS: `/tmp/newsblur-mac-release-build-76.log` and `/tmp/newsblur-device-release-build-76.log`. Both app bundles pass strict recursive signature verification and contain no XCTest bundle. The Mac distributable uses a fresh DerivedData directory and the normal disabled incoming-network entitlement; the test-host loopback allowance is absent.

- Mac: installed build 336, bundle `com.newsblur.NB-Alpha`, at `/Users/sclay/Applications/NB Alpha.app`. Replacing `/Applications/NB Alpha.app` was denied because that older copy is root-owned and the Applications directory restricts unlinking. Noninteractive sudo also required a password. The old app remains unchanged. Launch the user-folder copy explicitly. The final desktop-control attempt still fails at native-pipe startup, so a manual launch and full-window Mac check remain unverified.
- ClayPad Air: installed and launched successfully. A subsequent process query confirms the installed app is still running as PID 1771. Evidence: `claypad-install-76.json`, `claypad-launch-76.json`, and `claypad-processes-76.json` under `/tmp/newsblur-scroll-evidence`.
- ClayPhone SE 3: installed successfully (`clayphone-install-76.json`). Launch was rejected because the device was locked (`clayphone-launch-76.json`); unlock was requested before retrying.
- Simulator: Xcode left the existing iPhone 17e shut down after testing. The same device was restarted, and NB Alpha was launched normally with `NB_SCROLL_PERFORMANCE=0`. `/tmp/newsblur-scroll-evidence/ios-final-normal-launch-76.png` shows the preserved `samuel` session and feed list.

All changes remain uncommitted and unstaged in the performance worktree. No commit was made during this follow-up.
