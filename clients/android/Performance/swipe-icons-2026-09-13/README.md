# Swipe destination icons

Validated on the existing Pixel 5 API 35 emulator, signed in as samuel. `before.png` reproduces the clipped generic "Read / unread" text revealed by a swipe.

## Behavior

- Story read/unread toggles resolve to the destination state. The thin read ring uses the iOS `indicator-read.svg` geometry; the thick unread ring uses Android's matching existing asset.
- Save offers the filled saved-story clock. Once saved, the next swipe offers an outline unsave clock.
- Feed bulk-read, notifications, statistics, actions, share, Ask AI, and training use their corresponding icons.
- The reveal contains no text. Accessibility announcements still name the concrete destination action, with bulk-read wording for feeds.
- Releasing a committed swipe executes the destination that was shown. Canceled swipes return the row without performing the action.

## Evidence

- `light-*`, `dark-*`, `black-*`, and `sepia-*`: held previews of story read, feed bulk-read, and feed notifications. Every captured gesture was returned to its origin and canceled. No feed was marked all read.
- `toggle-read-before.png`, `toggle-read-offers-unread.png`, and `toggle-read-restored.png`: a single story was marked read, its next swipe showed the unread icon, and it was marked unread again. Both the cell appearance and destination icon changed.
- `toggle-save-before.png`, `toggle-save-offers-unsave.png`, and `toggle-save-restored.png`: the same story was saved and then unsaved again. The saved badge and destination clock changed together.
- `action-*.png`: other action icons were previewed without executing the actions.
- `reverse-save.png` and `reverse-read.png`: reversing the same held gesture changes the destination icon from save to read. Returning to the origin and releasing cancels both actions.

The runtime state checks temporarily used All stories so the test story remained in the list. Theme and gesture preferences were changed for coverage, then returned to sepia with rightward navigation and the existing leftward read toggle. The feed filter was returned to Unread only.

## Checks

- 382 Debug unit tests passed, zero failures/errors/skips.
- 382 Alpha unit tests passed, zero failures/errors/skips.
- Both APKs build successfully; the final Debug APK is installed on the emulator.
- Five new `GestureSwipeActionTest.kt` tests cover both toggle directions, explicit actions independent of state, icons for every enabled action, and disabled gestures.
- Existing `RowSwipeDecisionTest.kt` coverage exercises cancellation and commit thresholds.
- Focused Kotlin style checks and a separate source review passed.

The Samsung is not currently connected to ADB, so physical NB Alpha installation remains pending. Production NewsBlur has not been replaced.
