# Related story read states and article navigation

Validation on Samuel's account, September 13, 2026. Android worktree: `android-scroll-performance`.

## Behavior

- Android imports and saves the web account's `cluster_mark_read` preference. Samuel's saved value is enabled; an absent preference retains the web's disabled default.
- Reading a parent, including by scrolling past it, marks the eligible matching/related stories read. Server-expanded read hashes are reconciled with local changes without counting the same story twice or undoing a newer unread action.
- Child rows reflect read state wherever the story appears. Read receipts survive delayed responses and offline actions.
- Article footers show matching and related stories in web order, including on the first article open and after Activity recreation. Tapping an entry opens it in its own feed.

## Live checks

Used the existing logged-in Pixel emulator (`com.newsblur`) and Samsung S22 (`com.newsblur.alpha`). No instrumentation tests, account reset, or mark-all-read action.

| Check | Result |
| --- | --- |
| Original Samsung reproduction | Rust parent had two matches in titles but no article footer; cached child read state differed from parent. |
| First article open | Rust article footer showed both matches immediately. |
| Cross-feed footer tap | jodrellblank match opened the matching Hacker News: Best Comments article. |
| Older related story | The 10-day-old Google News child `9959362:8b82ea` now opens directly with its own content and matching-parent footer, replacing the reproduced long pagination wait. |
| Scroll parent past threshold | Engadget Beyerdynamic parent `5523704:698641` and match `9959362:8b82ea` both changed from local unread (0) to read (1). The child row dimmed while still visible. |
| Server read persistence | Both hashes absent from their respective `/reader/unread_story_hashes` responses after scrolling. |
| Preference saving | Switched off in Android and verified server false, then on and verified server true. Left enabled. |
| Database upgrade | Existing emulator database upgraded to version 8 without losing the logged-in session or cached stories. |
| Toolbar state through footer tap | Opened the Tom's Hardware related article from Engadget with the toolbar hidden, then visible. The destination retained each state. |

## Screenshots

- [Before: titles](before-title-list.png), [before: article](before-detail.png)
- [Scroll before](scroll-before.png), [scroll after](scroll-after.png)
- [Cross-feed navigation](related-navigation.png), [older match](old-related-navigation.png)
- [Preference enabled](preference-enabled.png), [disabled](preference-disabled.png)
- [Light](light-detail.png), [dark](dark-detail.png), [black](black-detail.png), [sepia](sepia-detail.png)
- [Related navigation, toolbar hidden](related-toolbar-hidden.png), [toolbar visible](related-toolbar-visible.png)

## Query cost check

On a local copy of the phone's SQLite database (15,123 stories, 684 feeds), the new child-membership index resolves affected parent rows without scanning every story's cluster JSON. The copy retained all rows and passed `integrity_check` after backfill.

For 100 lookups on that Mac-hosted database copy, the indexed queries took 0.007 seconds total versus 4.927 seconds for JSON scans. The scan median was 43 ms and p95 89 ms. Indexed queries were mostly below SQLite CLI timer resolution. These are database query measurements, not device frame rates or end-to-end UI speed claims.

Raw evidence: [query plan](sqlite-query-plan.txt), [timing](sqlite-query-timing.txt).

## Final validation

`testDebugUnitTest`, `assembleDebug`, and `assembleAlpha` pass: **471 tests, zero failures/errors**. Tests cover preference parsing/save failure, matched versus related eligibility, idempotent counts, offline and stale-response ordering, first/restored article metadata, exact-target lookup/cancellation, reader insets after theme recreation, and toolbar visibility through wrapped fragment contexts.

An additional live RELATED-tier case used Engadget's Alienware 560Hz story (`5523704:a1a227`). Its Tom's Hardware child (`8077169:08e39e`) appeared in the article footer and its embedded read state became true when the parent was read.

Related navigation also exposed a toolbar-state bug: Hilt wraps the fragment context, so a direct activity type check lost the current hidden state. Both direct reader navigation and the intermediate feed-list path now unwrap the context before inheriting that state. Two regression tests reproduced the failure and pass with the fix; visible readers and fresh list entry retain their existing behavior.

Theme recreation exposed a pre-existing framework inset problem: fitting ancestors consumed the status/navigation insets and exposed the prior screen's background. The reader now owns those insets consistently. The live before/after diagnostic changed from root Y=91/padding=0 to root Y=0/padding=91, with a readable themed status bar. Temporary diagnostics were removed from the final builds.

The Samsung remained locked for final interactive verification. NB Alpha installation succeeded without touching the production NewsBlur package; final UI checks used the authenticated emulator.

Restored the emulator's Engadget and Blogs filters to Unread and its theme to Light after testing. The account's related-story mark-read preference remains enabled.
