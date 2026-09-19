# Shared discovery view preference and Related Sites panel

Validated on the connected Samsung Galaxy S22 (SM-S901U1, Android 16), using the existing account and debug installation. No instrumentation APK, subscriptions, version bumps, or commits.

## Changes

- Add + Discover Sites and Related Sites share the existing `discover_feeds_view_mode` preference. List is the default when no valid choice exists. Explicit List or Grid choices survive closing screens and restarting the app, and retained view models observe changes from the other screen.
- Both screens use the same 24dp grid/list assets and accessible “Show grid” / “Show list” descriptions. Related Sites has a 48dp touch target instead of the old raised text button.
- Related Sites uses the standard `ReaderSheetPalette` surface and border, 18dp corners, 12dp elevation, and a header divider. Its source button, anchoring, entrance animation, feed actions, and existing List/Grid content behavior are retained.

## Regression evidence

Before implementation, the default-List unit test failed, the device icon test reported `Related Sites uses a text GRID/LIST button`, and the persistence script failed its initial List assertion because Add + Discover ignored the existing saved List preference. [Original Related Sites panel](screenshots/related-before.png).

The focused Gradle run passed **46 tests in 6 suites**, with zero failures, errors, or skipped tests:

```sh
env JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew :app:testDebugUnitTest \
  --tests com.newsblur.preference.Test_DiscoveryViewPreferences \
  --tests 'com.newsblur.discover.*' --tests 'com.newsblur.addsite.*'
```

Coverage includes absent/invalid preferences, existing explicit choices, cold view-model instances, stale saved state, changes in both directions, preference clearing, and listener cleanup. `:app:installDebug` compiled and installed the resulting APK on the Samsung.

## Samsung checks

`ruby test_remembered_view.rb <serial>` passed the complete sequence: List to Grid in Add + Discover, screen dismissal/reopening, force-stop/relaunch, shared Grid in Related Sites, switching back to List, reopening Related Sites, List in Add + Discover, and another force-stop/relaunch. The phone's original explicit List choice is preserved at completion.

`ruby test_related_toggle.rb <serial>` passed on the installed app. It checks that no visible GRID/LIST text button remains, the toggle has an accessible description, and tapping it changes the view mode. [List](screenshots/related-light.png) shows story previews; [Grid](screenshots/related-grid.png) hides them as before.

Device helpers use fresh UI hierarchies and require the existing logged-in account with Slashdot visible in the feed list. The persistence helper starts with List selected and ends with List selected. They do not clear app data or invoke Add/Subscribe.

## Visual checks

Both screens were checked in each supported palette:

| Theme | Related Sites | Add + Discover |
| --- | --- | --- |
| Light | [Panel](screenshots/related-light.png) | [Screen](screenshots/discovery-light.png) |
| Dark | [Panel](screenshots/related-dark.png) | [Screen](screenshots/discovery-dark.png) |
| Black | [Panel](screenshots/related-black.png) | [Screen](screenshots/discovery-black.png) |
| Sepia | [Panel](screenshots/related-sepia.png) | [Screen](screenshots/discovery-sepia.png) |

The panel heading and toggle remain usable with [1.3x system text](screenshots/related-large-font.png) and in landscape, where both [List](screenshots/related-landscape.png) and [Grid](screenshots/related-landscape-grid.png) were selected successfully. The source toolbar stays visible below the panel.

The capture helper initially waited for a folder picker below the visible viewport; screenshots confirmed the results were loaded. It now waits for the visible feed title. A rapid pair of Back events also raced popup dismissal once; the reusable helper now waits for a fresh hierarchy after Back. Neither required an application change.

AUTO theme, font scale 1.0, portrait rotation, and automatic rotation are restored. List remains selected, all animation scales are normal, and the crash buffer is unchanged from the baseline. `git diff --check` passes. HEAD remains `f7a78c53f`; all work is uncommitted.
