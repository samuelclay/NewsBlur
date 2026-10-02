# iPhone Duo simulator testing

Use the **NewsBlur Alpha** scheme (`com.newsblur.NB-Alpha`) and the existing logged-in Duo simulator. This guide describes repeatable checks; commit-specific results and recordings belong in the pull request and its test artifacts.

## Device Hub and simulator setup

Run `python3 clients/ios/run_ios.py list` from the repository root and reuse the booted Duo's UDID. Do not erase, clone, or replace the logged-in device. Device Hub supplies the actual Closed, Partially Open, and Open poses. Resizing a window or overriding size classes does not establish fold coverage.

Use `run_ios.py` for simulator installation, launch, screenshots, and recording. Set `IOS_BUNDLE_ID=com.newsblur.NB-Alpha`. For this simulator, `IOS_SIM_DISPLAY=1` selects the outer display and `IOS_SIM_DISPLAY=3` selects the inner display. An inactive display can return a black image; check the selected pose before diagnosing an app failure.

Focus Device Hub before sending input. Refresh its window bounds before translating screenshots into pointer coordinates, accounting for Retina scaling. Confirm each requested pose or rotation in the visible device; a command reporting success is not enough. A locked Mac prevents reliable Device Hub interaction and window recording.

Run tests with `-parallel-testing-enabled NO`. Do not run multiple test invocations against the same simulator. `-collect-test-diagnostics never` can shorten deliberately failing reproduction runs without removing assertion output or explicit attachments.

## Running the tests

Replace `DUO_UDID` below with the booted device identifier:

```sh
xcodebuild -project clients/ios/NewsBlur.xcodeproj \
  -scheme 'NewsBlur Alpha' \
  -destination 'platform=iOS Simulator,id=DUO_UDID' \
  -parallel-testing-enabled NO \
  '-only-testing:NewsBlurAlphaPerformanceTests/Test_FeedToolbarLayout' \
  '-only-testing:NewsBlurAlphaPerformanceTests/Test_StoryTitlesHeaderBarLayout' \
  test
```

`NewsBlurAlphaUITests` depends only on Alpha. Do not combine the production NewsBlur UI-test dependency with Alpha in a temporary scheme: both app targets emit the `NewsBlur` Swift module. The existing `ReaderUITests.swift` and `AddSiteUITests.swift` also compile into the Alpha UI target for conventional-device fixtures.

Live audits activate the existing authenticated app. Opt-in variables use their **unprefixed** names in an Xcode scheme. When passing them through `xcodebuild`, prepend **`TEST_RUNNER_`**, for example:

```sh
env TEST_RUNNER_NEWSBLUR_LIVE_DUO_UI_TESTS=1 \
  xcodebuild -project clients/ios/NewsBlur.xcodeproj \
  -scheme 'NewsBlur Alpha' \
  -destination 'platform=iOS Simulator,id=DUO_UDID' \
  -parallel-testing-enabled NO \
  '-only-testing:NewsBlurAlphaUITests/Test_DuoLiveUI' test
```

| Unprefixed variable | Audit |
| --- | --- |
| `NEWSBLUR_LIVE_DUO_UI_TESTS=1` | `Test_DuoLiveUI`: actual taps, scrolling, full-screen overlays, edge gestures, and divider resizing |
| `NEWSBLUR_DUO_PHOTO_FEED` | Optional subscribed photo-feed name for the image edge-cancellation audit; defaults to `STREET ART UTOPIA`, with a clear skip when the source is unavailable |
| `NEWSBLUR_LIVE_DUO_LAUNCH_TESTS=1` | Run a selected cold-launch test in `Test_DuoPresentation` alone, starting Open |
| `NEWSBLUR_LIVE_DUO_FOLD_TESTS=1` | Selected live reader fold test; operate Device Hub when the test requests a pose |
| `NEWSBLUR_LIVE_DUO_BACK_TESTS=1` | `test_liveClosedBackKeepsReturningFeedsAtTheirFinalTopEdge`, starting Closed |
| `NEWSBLUR_LIVE_DUO_BACK_FOLD=1` | With the Back variable above, start Open; fold Closed when the test prints its readiness marker |

Preserve the account, original theme, full-screen preference, orientation, and search state. Avoid bulk mark-read, subscription edits, purchases, or posting. Open destructive confirmations only to inspect and cancel them. Ordinary article selection can mark articles read; prefer already-read stories when exercising repeated reader transitions.

## Behavior and regression map

| Area | Required behavior | Coverage |
| --- | --- | --- |
| Closed feed controls | One continuous four-filter intelligence group using the original artwork; separate Add and Settings buttons in the native side rail; UIKit overflow as needed | `test_duoClosedFeedControlsParticipateInSystemVerticalBar` |
| Account header | Account details scroll with Feeds; no unused horizontal header or status-bar band | `test_duoClosedAccountHeaderScrollsWithFeedsWithoutTopBarGap` |
| Closed Back after folding | Tapped Back returns Feeds at its final top edge throughout the animation; cancelled interactive Back preserves the outgoing story header | `test_liveClosedBackKeepsReturningFeedsAtTheirFinalTopEdge`, `test_duoInteractiveBackKeepsOutgoingHeaderUntilTransitionFinishes` |
| Story-list controls | Native vertical toolbar when closed; obsolete bottom space removed except for active search | `test_duoClosedStoryListControlsParticipateInSystemVerticalBar`, `test_verticalStoryListFooterOnlyReservesSpaceForActiveSearch` |
| Story-list heading | Leading Feeds action, centered source title with original-color favicon, trailing Settings; header minimizes only with its own list | `Test_StoryTitlesHeaderBarLayout`, `Test_DuoLiveUI` |
| Open launch and navigation | Normal launch shows Feeds beside the selection prompt/titles. Source selection keeps Feeds visible; only explicit story selection moves into titles plus readable article | `DetailViewControllerTests`, `Test_FeedDetailEmptyState`, live launch tests in `Test_DuoPresentation` |
| Source entrance | Every explicit feed/folder selection slides loaded rows rightward from beneath stationary Feeds with a short fade; clipped at the column boundary; late responses do not replay it | `test_liveOpenSourceSelectionsAnimateTitlesThenShiftIntoReading` |
| Sidebar stability | Queued source loads and automatic reader work cannot undo an explicit Feeds reveal; tiled Feeds pair with titles, never a squeezed article | `DetailViewControllerTests`, `test_liveDuoReaderScrollAndSidebarRoundTrip` |
| Full-screen reading | Horizontal expansion toggle persists per account and across source changes/folds; native titles and Feeds overlays share a remembered, draggable width | `DetailViewControllerTests`, `Test_DuoLiveUI`, live full-screen launch/fold tests |
| Empty full-screen reader | Outside taps cannot dismiss either source overlay before article selection; source controls, dialogs, and resize handle remain interactive | `test_liveFullscreenLaunchShowsFeedsOverlayUntilStorySelection` |
| Reader header and theme | Feed title/gradient stay pinned while reading, follow top pull-down, and remain opaque over text/photos. Side rail uses the app header palette | `Test_FeedToolbarLayout`, live reading UI journey |
| Reader transitions | Story-title taps, previous/next actions, and rapid replacements show the selected document without a temporary transparent header or stale article | `Test_StoryDetailLoading`, `Test_StoryFirstPageLoading`, live reading journey |
| Reader scrolling | Correct indicator position, no obsolete bottom-toolbar reservation, native top/bottom bounce for short and long articles | `Test_FeedToolbarLayout`, actual drag and wheel checks |
| Fold/rotation continuity | Keep the same article, document generation, readable viewport, and reading position; restore valid compact navigation and expanded controls without crashes | Live fold tests in `Test_DuoPresentation`, `DetailViewControllerTests`, reader UI tests |
| Retained controllers | Offscreen readers cannot alter the visible controller's navigation bar or Back gesture | `test_retainedReaderLayoutDoesNotUnhideAnotherControllersNavigationBar`, `test_retainedReaderFoldPreservesVisibleControllersBackGesture` |
| Dialog routing | Visible popover anchors survive source changes; browser Close works; Preferences picker centers are tappable; keyboard focus survives unrelated refreshes | `Test_DuoDialogRouting`, `Test_DuoPresentation`, Add Site UI tests |
| Trainer context | Training retained article A while browsing source B preserves the article context and B's selection | Trainer regression tests and live reader dialogs |
| Social/profile rendering | Current Find Friends controller receives responses; profile/activity rows fit content; deleted-user rows stay collapsed; badges fit below search | `Test_FindFriendsRendering`, `Test_InteractionCellLayout`, live social-dialog checks |
| Account and asynchronous loading | Empty states commit valid table rows; late callbacks cannot select an outgoing source; account reset clears owned presentation state | Authentication, detail, article-loading, and first-page-loading suites |

## Manual verification matrix

Exercise Closed, Partially Open, and Open in each usable orientation. Include:

- Feeds, individual feeds, folders, All Site Stories, and a selected empty source.
- First source load, repeated selection, rapid source changes, story taps, previous/next, and returning to Feeds.
- Scroll both columns independently from top to bottom and back; hold top and bottom overscroll. Test direct dragging and trackpad/mouse-wheel input.
- Normal two-pane and full-screen reading; native edge reveal and cancellation; overlay dismissal after story selection; divider movement in both directions.
- Open-to-Closed-to-Open and Open-to-Partially-Open transitions during loading and with a scrolled article. After folding, test tapped Back and completed/cancelled interactive Back.
- All four themes: light, sepia, medium, and dark; both paging directions and configured horizontal toolbar positions; Reduce Motion.
- Add/Discover with keyboard, Preferences, site/story menus, search, mark-read confirmation cancellation, Share, Trainer, font settings, notifications, account/profile, and supported management dialogs.
- Native overflow when capacity actually forces a control into it. Invoking an action directly does not verify selecting it from overflow.

Record transitions and inspect intermediate frames for double wipes, blank bands, header flashes, clipping over Feeds, or post-animation jumps. Capture actual loaded article content, not just layout flags or loading placeholders.

Conventional iPhone and iPad checks remain required: portrait/landscape reading, Back gestures, header/footer controls, full article width, dialogs, and iPad column changes. Duo-specific ownership must restore the previous standard behavior when it ends. Synthetic trait tests complement these runs; they do not replace actual device coverage.

## Reporting results

Keep failing reproductions distinct from passing follow-ups. Record the tested commit, target, runtime, pose, exact test selection, and artifact links in the PR. Attribute skipped checks to their actual device or environment prerequisites.

Report required application-suite results separately from optional hosted UI smoke outcomes. A green job with a non-gating smoke timeout does not establish a passing UI run. Recheck required CI and automated review threads on the final pushed commit before marking the change ready.
