# Next-button title-list reveal

Worktree: `ios-scroll-performance`. Target: NB Alpha. Existing article-selection animation and cell visuals are retained.

## Reproduction and cause

The fourth 200-point parent title is partly visible in a 700-point title pane. The real list callbacks used by `StoryPagesObjCViewController.m` first select/reveal that title, then mark it read and call `redrawUnreadStory`.

`changeActiveFeedDetailRow` starts an animated `scrollToRowAtIndexPath`. Immediately afterward, `redrawUnreadStory` calls `reloadRowsAtIndexPaths` with no row animation. This still changes UIKit's presentation during the active scroll. It also clears the row-height cache and reconstructs cluster descriptors, even though read state changes no geometry.

Run 145 reproduces the conflict before the production change. Both exact heights and 44-point estimates fail. Each reveal reloads one row; sampled table presentation offsets jump from zero to approximately -565 or -621 before proceeding to the final offset of 622. The regression asserts forward-only movement and no row reload. Before screenshots are attached to `/tmp/newsblur-scroll-evidence/next-title-reveal-before-145.xcresult`.

## Fix and validation

`redrawUnreadStory` updates existing visible parent and related cells through the read-state refresh path. Saved and shared badges update even when read state is unchanged. It avoids redundant selection calls. Content-changing share responses retain their separate sizing refresh. The title's existing destination and article animation are unchanged.

Run 146 passes the reveal regression with exact and estimated heights: zero row reloads, forward-only movement from zero to 622, and 17–19 distinct sampled positions. This is a sampled UIKit presentation trajectory, not a GPU frame-rate measurement. Two additional read/save/share tests fail because their old fixture did not provide a controller view; that fixture is corrected before subsequent runs.

The original screenshot of the running samuel session is `/tmp/newsblur-scroll-evidence/next-list-baseline-145.png`. Test stories are synthetic and do not consume the account's unread stories. No Mark All Read action is used.

Run 150 passes all **18 focused tests** in 8.227 seconds, including a real Next-button integration fixture with both landscape panes. The button invokes the real pager delegate, selection, local read-state mutation, and list redraw callbacks; only network sync is intercepted. It checks the actual drawn cell position as well as table bounds, with timestamp-aware limits on frame-to-frame movement. The title moves continuously from y=660 to y=38, with a maximum sampled step of 54 points. The article also retains its normal animated movement. Only the destination is newly read/synced, and the following story remains unread.

The additional visual-state coverage checks saved/shared indicators changing both ways, related-mark-read enabled/disabled, and individual related-story read changes while the parent stays unread. Current related-story state is resolved by hash from the current parent instead of an older row descriptor. Existing read fades, reuse, reduced motion, offscreen behavior, and theme/image-side pixel parity also pass.

Capture caveat: run 148 took a `drawHierarchy` screenshot during movement, producing an artificial step in the measurement. Run 149 removes that mid-motion capture and reveals a separate fixture setup transaction affecting the article. Run 150 waits for two actual display ticks and verifies the prepared source state before pressing Next. Its measurement contains no screenshot or forced layout. Before/after hierarchy captures remain attached. Production article-animation code is unchanged by this fix.

Run 151 executes the full 385-test iOS suite. All Next/reveal/read-state tests pass, and 384 test cases pass overall. The existing cold-feed-icon benchmark times out waiting for background preparation after 350 of 651 disk reads, then reports the remaining 301 reads on the foreground path. That single test has three failing assertions; it is investigated separately rather than reported as a green full run. Bundle: `/tmp/newsblur-scroll-evidence/next-title-full-ios-151.xcresult`.

Run 152 executes the full 388-test Mac Catalyst suite. All Next/reveal/read-state tests pass and 387 cases pass overall. The existing status-bar saved-position test checks its asynchronous writer after a fixed 50 ms delay and sees no write yet. The fixture now waits for the actual writer and delivery of the cancelled old read. The cold-icon fixture now fences its injected utility worker instead of polling one cache entry; all 651-image, bitmap, and disk-read assertions remain. Neither correction changes production code.

Run 153 passes all **18 focused tests on the physical ClayPad Air** (iPad Air 5, iOS 26.2.1) in 4.902 seconds. The actual Next action produces zero row reloads, forward-only title movement from 0 to 622, and continuous movement of the drawn fourth cell from y=660 to y=38. The largest sampled title step is 54 points. Article motion continues through intermediate positions, and only the destination becomes newly read. This is sampled presentation geometry, not a GPU frame-rate claim. Device screenshots are attached to `/tmp/newsblur-scroll-evidence/next-title-claypad-153.xcresult` and exported under `/tmp/newsblur-scroll-evidence/next-title-claypad-153-attachments/`.

Run 155 passes the four targeted iOS follow-up tests in 8.024 seconds: the cold-icon preparation benchmark, both Next/reveal tests, and the corrected asynchronous status-bar test. Cold preparation finishes with zero pending work, all 651 prepared keys, 651 unique worker disk reads, and zero foreground disk reads. Production icon rendering is unchanged; this run does not retroactively establish why run 151 stopped partway through preparation.

Run 156 passes all **20 targeted Mac Catalyst tests** in 6.688 seconds: both Next/reveal tests, all 16 read-state/visual tests, and both corrected asynchronous fixtures. The cold cache again retains all 651 prepared images with no foreground disk reads. Bundle: `/tmp/newsblur-scroll-evidence/next-title-followup-mac-156.xcresult`. Full-suite results above are reported as observed; only the affected tests are rerun after the fixture corrections.

Normal release builds 154 succeed for iOS devices and Mac Catalyst, pass strict recursive code-signature checks, and contain no XCTest plug-in. NB Alpha is installed and launched on ClayPad Air (PID 2037) and ClayPhone (PID 46272), with performance instrumentation disabled. Both processes are confirmed alive. The user-folder Mac app at `/Users/sclay/Applications/NB Alpha.app` is replaced and its signature verified; its previous copy is retained at `/tmp/newsblur-mac-before-next-154.app`. Manual Mac launch is not verified because the Computer Use connection remains unavailable. The root-owned `/Applications/NB Alpha.app` is unchanged.

Changes remain uncommitted at 17:08 Pacific on September 11, honoring the user's 18:00 commit embargo. The worktree remains on `ios-scroll-performance` at `8e63e63dd`; unrelated earlier work is preserved.
