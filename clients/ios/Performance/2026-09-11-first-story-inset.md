# First story position after launch

The first article after launching NB Alpha can appear below its intended position. The feed strip stays in place while the article's background, title, and body sit too low. Advancing two articles and returning corrects the layout. The user supplied two ClayPhone SE screenshots showing the same Daring Fireball article before and after that redraw.

## Reproduction before changes

All work uses the existing `ios-scroll-performance` worktree and NB Alpha. The already booted iPhone 17e simulator (`3AD72704-02E5-4B1D-AA90-02413F046991`) remains signed in as samuel. Each reproduction restarts the app without clearing its data, opens a list, opens its first story, then advances twice and returns twice. Mark all read is never invoked.

The initial folder attempt used a Neowin article that loaded Text view and did not retain the shift. The subsequent folder and single-feed attempts both reproduce it in Story view:

| Context | Article | First open | After two pages forward and back |
| --- | --- | --- | --- |
| Engadget single feed | Where should Apple go after the iPhone Duo? Bring on smaller and larger foldables | `story-offset-single-first-53.png` | `story-offset-single-return-53.png` |
| Any Broken Feeds folder | For China, a Mock A.I. Attack on WeChat Signals a Dangerous New Era | `story-offset-folder-first-54.png` | `story-offset-folder-return-54.png` |

Evidence is under `/tmp/newsblur-scroll-evidence`. The full interactions are recorded in `story-offset-single-open-before-53/scroll.mp4` and `story-offset-folder-open-before-54/scroll.mp4`. Both pairs were visually inspected before any production edit. The article is 12 points too low on the simulator's first open, matching the difference between the 59-point fallback status area and this simulator's 47-point status area. The SE's 20-point status area produces the larger 39-point discrepancy in the user's screenshots.

Pixel comparison confirms the displacement independently of visual estimates. In the article band spanning 23% through 43% of each screenshot's height, the first and returned simulator images match with zero mean RGB difference after a 36-pixel translation (3 pixels per point). The user's SE images match after a 78-pixel translation (2 pixels per point). Measurements are saved in `story-offset-before-pixel-comparison.txt`; the local analysis script is `/tmp/newsblur-story-offset-measure.swift`. This measures article position, not frame rate or loading latency.

## Regression and cause

Test-first commit `420d74b8f` adds separate folder and single-feed cases to `StoryDetailLoadingTests.swift`. They exercise article preparation, readiness, release from the preparation host, and the real `changePage` implementation before the native push attaches the story controller. Their isolated window supplies the SE's 20-point top safe area.

Both cases fail on the old code in `story-offset-red-55.xcresult`: two tests, six expected assertions, no unexpected failures. Initial preparation correctly uses a 64-point inset. During handoff it changes to **103**, and the reading offset changes to **-103**, even though the visible navigation window still reports the same 20-point safe area. The log is `/tmp/newsblur-story-offset-red-55.log`.

`StoryPagesObjCViewController.m` clears the pending presentation page and returns its web view to the detached page container before calling `changePage`. Its top-inset resolver can no longer see the preparation window and does not consult the still-visible feeds navigation window. It temporarily falls back to 59 points. When native presentation supplies the correct window again, the inset is corrected but the article retains the extra offset. Later paging establishes the correct reading position.

## Fix

Fix commit `06b9903df` makes the resolver use the loaded feeds navigation controller's window when neither the story controller nor the preparation web view has a window. An attached story window remains first priority, followed by the preparation window. The fix retains the actual window geometry across the handoff without changing article HTML, gradient styling, content padding, or reading-offset behavior.

Additional cases cover a saved reading position through the real handoff, an already hidden toolbar, and the attached article window taking priority over a different navigation window. The window-priority case also checks that updated safe-area geometry is read rather than cached.

## Regression results

The full Alpha suite passes **326 tests with zero failures in 104.102 seconds**, including all 61 article-loading cases and seven detail-scroll cases. `xcodebuild` exits zero. Evidence: `story-offset-full-after-56.xcresult`, `/tmp/newsblur-story-offset-full-after-56.log`, and `/tmp/newsblur-story-offset-after-build-56.log`.

Both first-article cases now report an inset of 64 and reading offset of -64 throughout handoff. The hidden-toolbar case retains its -20 offset, and the saved-position case retains its 500-point reading position. No story-content or gradient simplification is involved.

## Live validation after the fix

After a fresh launch, the same Engadget article opens correctly in Story view. Its first-open and returned images (`story-offset-single-first-after-56.png`, `story-offset-single-return-after-56.png`) match with **zero vertical displacement** and zero mean RGB difference in the measured article band. The full sequence is in `story-offset-single-open-after-56/scroll.mp4`.

The folder's newly fetched first article was a TechRadar story that automatically loaded Text view. Its first-open and returned images also match at zero displacement (`story-offset-folder-first-after-56.png`, `story-offset-folder-return-after-56.png`), but that mode can redraw and conceal the original bug.

To verify the original Story-view path, a separate fresh launch used the same folder with All stories and the search term China to locate the previously read Google News article. The first opened article in that app session is the same one used in the red folder recording. Its corrected first frame, `story-offset-folder-story-first-after-57.png`, matches the old build's corrected return frame, `story-offset-folder-return-54.png`, at **zero vertical displacement** with zero mean RGB difference. This establishes that the first Story-view draw now lands directly at the former corrected position. The evidence is `story-offset-folder-corrected-reference-comparison.txt` and `story-offset-folder-story-open-after-57/scroll.mp4`. The search recording's Next control starts a fetch, so that check uses the established corrected frame as its reference rather than treating the two Next taps as proof of completed paging.

Both first-open paths therefore remove the measured 12-point simulator error. The SE-specific 39-point handoff discrepancy is covered by the separate folder and single-feed regression cases. All comparison screenshots were inspected; the update preserves the title, gradient, feed strip, images, and article body.

After verification, the temporary folder search was cleared and its Unread filter restored (`story-offset-restored-unread-57.png`). The simulator returns to samuel's feed list with performance probes disabled.

## Device build

The signed Release build succeeds (`/tmp/newsblur-story-offset-device-build-56.log`), and `codesign --verify --deep --strict` passes. The executable SHA-256 is `f79335861fc37a818b7874d267f2764871d5f0ec948991081e1510619767abe6`.

The same `com.newsblur.NB-Alpha` build was installed wirelessly on ClayPad Air (`C78768E8-4867-5C24-8298-FF27334049EE`) and ClayPhone SE 3 (`E62ABF72-70BD-5647-BC74-689A513A4EBE`). Install results both report success in `/tmp/newsblur-claypad-story-offset-install-56.json` and `/tmp/newsblur-clayphone-story-offset-install-56.json`.

ClayPad Air launched in the foreground as process 1702, with performance probes disabled (`/tmp/newsblur-claypad-story-offset-launch-56.json`). The first ClayPhone launch was denied because the phone was locked (`/tmp/newsblur-clayphone-story-offset-launch-56.log`). After the user unlocked it, the updated app launched successfully in the foreground as process 43486, also with probes disabled (`/tmp/newsblur-clayphone-story-offset-launch-unlocked-56.json`). Physical-device interaction is not part of the screenshot comparison above.
