# Discover story preview styling

Implementation: `ec1dcacbd` on `android-add-discover-sites`.

The original Android discovery parser reduced story objects to title strings, losing the images, author, publication date, and excerpt already supplied by the server. The list rendered those strings as plain text. `before.png` captures that behavior on the Samsung device before editing.

The revised list follows the web story-title hierarchy and iOS thumbnail treatment: semibold headlines, muted author/date metadata, short plain-text excerpts, rounded right-hand thumbnails, and separators. Stories without images use the full row width. Thumbnail URLs prefer the server's secure thumbnail mapping; HTML entities are decoded for display. Colors derive from the existing theme palette, with stronger contrast for small metadata text.

The regression test failed against the original implementation before the fix. All 34 focused Android tests pass afterward (24 discovery and 10 existing Add Site tests), and the debug APK builds successfully. New coverage checks retained metadata, missing images, script/style removal, image fallbacks, and UTC dates.

References: web `media/js/newsblur/views/add_site_view.js` and `story_title_view.js`; iOS `DiscoverFeedCardView.swift` and `DiscoverFeedsModels.swift` from the `ios-add-discover-sites` worktree.

## Physical device checks

Samsung SM-S901U1, Android 16, final debug APK installed with login preserved. No instrumentation APK used.

All four themes (light, dark, black, sepia) were inspected in portrait and landscape with live stories and loaded thumbnails. The eight captures have verified dimensions of 1080×2340 or 2340×1080. Portrait captures show the complete first feed card; landscape captures show the scrollable story rows at their expanded width.

Additional live cases:

- `author-and-images.png`: Golden Hill Software, author names, relative dates, and three loaded story thumbnails.
- `mixed-images-and-entities.png`: Proton, two stories without images followed by one with an image; `Australia&#8217;s` displays as `Australia’s`.
- `without-images.png`: Hacker News, full-width rows without thumbnails or authors.
- `larger-text.png`: the story rows at Android font scale 1.3, retaining thumbnail alignment and readable wrapping.

The original automatic theme, font scale 1.0, and automatic rotation were restored after checking. No subscriptions were changed, and the device crash log was empty. The revised build remains installed.
