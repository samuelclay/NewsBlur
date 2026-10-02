# Related Sites uses the shared discovery preview

Validated on the connected Samsung Galaxy S22 (SM-S901U1, Android 16). The existing account was retained; no instrumentation APK or subscription changes were made.

## Implementation

`DiscoveryFeedCard.kt` now owns the complete card used by Add + Discover Sites, the Related Sites popup, and the full Related Sites activity. It includes story thumbnails, excerpts, author/date text, selected-story highlighting, and the Try / folder / Add row. `DiscoveryActionEffects.kt` shares exact-story routing and subscription sync between the hosts.

The old Related Sites API model discarded story content, timestamps, and secure image metadata. Those fields are retained, and `RelatedDiscoveryModels.kt` passes them through the existing `DiscoveryStory.parse` rules. There is one excerpt/image parser and one card implementation.

Folder choices use a shared preference owned by the current login. Both screens observe changes, preserve full nested paths, display only the folder's leaf title, and retain the selection across app restarts. Missing/deleted folders fall back to Top Level, and stale hosts cannot overwrite another account's selection or add to it. Explicit nonroot launch context remains supported.

The popup keeps its Android surface, border, corners, placement, and entrance animation. It supplies an explicit Compose parent context and cleans up its owned recomposer on dismissal. The first device build exposed an unowned `PopupDecorView` lifecycle; the corrected build passed subsequent popup and full-screen checks.

## Tests

Both new regressions failed before implementation: rich story fields were discarded, and folder changes did not reach the other retained host.

```sh
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  ANDROID_SERIAL=R5CT601C8DA ./gradlew :app:testDebugUnitTest :app:installDebug
```

The complete suite passed **644 tests in 139 suites**, with zero failures, errors, or skipped tests. Coverage includes secure image fallbacks, sanitized excerpts, sparse/null API metadata, exact story identity, shared folder updates, cold instances, stale saved state, nested/deleted folders, account changes, and use of the latest full folder path in the Add API call.

## Samsung evidence

- [Before](screenshots/before.png): the older text-only related card.
- [Shared rich card](screenshots/related-rich-images.png): three Ars Technica stories with images and excerpts.
- [Shared action row](screenshots/related-action-row.png): Try, unlabeled folder selection, Add. The existing `discovery-actions-2026-09-18/test_action_row.rb` geometry check passes.
- [Nested folder selected in Related Sites](screenshots/related-nested-folder.png) appears in [Add + Discover](screenshots/discovery-shared-folder.png), including after force-stop/relaunch. Changing the choice in Add + Discover updates [Related Sites](screenshots/related-folder-from-discovery.png).
- Tapping the second Ars Technica story opens that [exact article](screenshots/story/opened.png); Back returns to [populated Try Feed titles](screenshots/related-try-feed-titles.png).
- The top-toolbar preference opens the [full Related Sites screen](screenshots/related-full-screen.png), which uses the same card and [folder controls in Grid](screenshots/related-full-screen-folder.png).

Add/Subscribe was not invoked against the account. Subscription routing and the selected folder's full path are covered by automated API-mock tests.

## Themes, rotation, and final state

The popup and folder row were checked in [Light](screenshots/final-related-light.png), [Dark](screenshots/related-dark.png), [Black](screenshots/related-black.png), and [Sepia](screenshots/related-sepia.png). Folder-row geometry checks also pass in all four themes.

The action row remains usable at [1.3x system text](screenshots/related-large-font-folder.png). After rotation, the [landscape folder picker](screenshots/related-landscape-folder.png) opens and selects successfully; switching back to List works.

AUTO theme, bottom toolbar, font scale 1.0, portrait orientation, and automatic rotation are restored. The shared preferences end on List and Top Level. No new crash entries appeared during validation of the corrected build. `git diff --check` passes, HEAD remains `f7a78c53f`, and all changes are uncommitted.
