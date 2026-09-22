# Android gesture parity validation, September 13, 2026

The gesture preferences now have separate Feed list, Story titles, and Reading a story groups. Feed and story swipe toggles are independent. Long press remains configurable when swipes are off. Existing Android left/right action selections are preserved.

Feed and primary story rows follow the finger and reveal the configured action. Releasing below the threshold returns the row without acting; vertical movement locks out horizontal actions. Recycled story rows cancel their pending movement. The left edge remains reserved for returning to feeds, including when story swipes are disabled or the interior right swipe is assigned to Show actions. Show actions opens the existing Android story action menu.

Reader double taps support separate one- and two-finger actions, and the left edge can return to titles or go to the previous story. The two-finger recognizer tracks pointer identities, including when the first finger lifts before the second. A failing regression was reproduced before that fix.

The story-list sub-bar in `activity_itemslist.xml` had 4 dp top and 8 dp bottom padding. Both are now 4 dp, reducing the bar height by 4 dp.

## Validation

- `:app:testAlphaUnitTest`: 356 tests, zero failures/errors.
- `:app:testDebugUnitTest`: 356 tests, zero failures/errors.
- `:app:assembleAlpha` and `:app:assembleDebug`: successful.
- Existing Pixel_5_API_35 emulator, signed in as samuel; no app data wipe or instrumentation APK.
- Feed right swipe visibly revealed Notifications and opened its checked options. Canceled without changing notification settings.
- Tapping the feed swipe toggle hid its left/right choices while retaining long press and independent story settings.
- Changed story right swipe through the preferences UI to Show actions; swiping a primary row opened its action menu while remaining in the story list.
- Long pressing a story opened Ask AI. No prompt was submitted.
- Left-edge navigation visibly followed the finger with Show actions selected, and with story swipes disabled.
- Two-finger double tap switched a real Engadget article from the feed excerpt to extracted original text. One-finger double tap opened the article in the system browser.
- Next selected the following Engadget story; the configured previous-story edge gesture returned to the prior article.
- Gesture settings were visually checked in light, dark, black, and sepia themes. Swipe underlay colors are centralized in `GestureThemeStyle.kt`.
- Test changes to theme, story swipes, right-swipe action, and reader edge behavior were restored to light, enabled, Back to feeds, and Back to story titles.
- NB Alpha was installed on the Samsung SM-S901U1 over its paired wireless-debugging connection. The production package remains version 14.3.1 (271). The phone was locked during final checks, so on-device gesture behavior and current Alpha login were not verified.

The emulator intermittently stalled at the Android System UI and adb levels, including visible System UI ANRs. The same AVD was restarted without clearing its account or data. These screenshots and interactions establish behavior and appearance; they are not a new frame-time benchmark. Earlier scrolling measurements and limitations remain in [RESULTS.md](../RESULTS.md).

## Screenshots

| Check | Evidence |
| --- | --- |
| Balanced sub-bar | [Light header](header-balanced-light.png) |
| Grouped preferences | [Light](settings-light.png), [Dark](settings-dark.png), [Black](settings-black.png), [Sepia](settings-sepia.png) |
| Reader preferences | [Reader settings](reader-settings-light.png) |
| Visible row movement | [Feed swipe](feed-swipe-action.png), [Story swipe](story-swipe-action.png) |
| Story long press | [Ask AI sheet](story-long-press.png) |
| Edge with row swipes disabled | [Interactive edge return](edge-back-swipes-disabled.png) |
| Reader two-finger action | [Original text](reader-two-finger-text.png) |
| Reader previous-story action | [Prior article restored](reader-previous-edge.png) |
