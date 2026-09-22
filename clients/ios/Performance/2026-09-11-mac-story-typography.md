# Mac story-list text consistency

Scope: NB Alpha, native Mac story-title rows in the `ios-scroll-performance` worktree. No iPhone/iPad style changes. SwiftUI alternate layouts and dashboard cards are outside this correction.

## Reproduction

The Mac Computer Use connection still fails during native pipe startup. The actual `FeedDetailTableCellView` draw pass is therefore captured and measured in the Mac Catalyst test host, using synthetic rows rather than consuming the account's unread stories.

Run 157 captures all four themes, selected/unselected, and read/unread states before the production edit. Its pixel regression fails because the feed title, story title, and secondary text have independent hardcoded palettes. In a light, unselected read row, the source is `#808080`, the story title is `#585858`, and the preview/byline are `#B8B8B8`. Selection can also override the read title color. This confirms a drawing-style mismatch rather than a missing read-state update.

Before bundle: `/tmp/newsblur-scroll-evidence/mac-typography-before-157.xcresult`. Before screenshots are exported in `/tmp/newsblur-scroll-evidence/mac-typography-before-157-attachments/`.

## Change

`FeedDetailTableCell.m` uses one Mac read-text color for headings, preview, and byline, including selected rows. Unread source and story headings share the existing title palette and Medium font weight. Preview and byline use the Book face; byline size stays 11 points. Related read title/date colors also match, with a Book 10 date drawn inside the existing measured allocation.

The read palette remains the existing preview palette: `#B8B8B8` for light/sepia, `#A0A0A0` for medium, and `#707070` for dark. Font sizes, cached title/preview metrics, row height, badges, images, and the compositor fade are preserved. All new behavior is guarded by `TARGET_OS_MACCATALYST`.

## Validation

- Run 158: **34 Mac tests pass** in 12.710 seconds. Covers actual glyph colors in 16 parent states and eight related read states, exact regular-byline glyph comparison, existing read fades and image/theme pixel checks, both Next/reveal regressions, and text layout cache/performance checks.
- Run 159: **16 iOS read-state/visual tests pass** in 2.136 seconds on the existing booted simulator. The iOS drawing branch remains unchanged.
- The normal samuel simulator session is relaunched after testing with performance instrumentation disabled.

After bundle: `/tmp/newsblur-scroll-evidence/mac-typography-after-158.xcresult`. After screenshots are exported in `/tmp/newsblur-scroll-evidence/mac-typography-after-158-attachments/`, including readable story-row examples as well as the glyph test matrix.

Normal Mac release build 160 succeeds. `/Users/sclay/Applications/NB Alpha.app` is updated and passes strict recursive code-signature verification; the installed executable matches the built executable (SHA-256 `6308652b8c4cf708563daea85829dab7cbcd1fe253754fd6d949981f1d5f4807`). The previous user-folder app is retained at `/tmp/newsblur-mac-before-typography-160.app`. Manual launch remains unverified because Computer Use is unavailable. The root-owned `/Applications/NB Alpha.app` is unchanged.

At 17:29 Pacific on September 11, all changes remain uncommitted in the existing worktree, honoring the 18:00 commit embargo. No release is submitted or version bumped.
