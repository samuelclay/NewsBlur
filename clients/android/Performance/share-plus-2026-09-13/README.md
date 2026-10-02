# Story long press and Add site icon

The previous story-title long press opened Ask AI because the gesture-menu port used Ask AI as the preference and settings-state defaults. Both now default to Share. Explicit saved choices remain unchanged; invalid saved values fall back to Share.

The feed-list plus was a stretched button background with bottom-only positioning. It now uses an inset image in a 36dp button, with 6dp padding and vertical centering against the filter selector. The existing theme background and icon color are reused.

## Validation

- The preference regression reproduced two failures before the change. All five GesturePreferencesTest cases pass in Debug and Alpha after the fix, including preservation of an explicit Ask AI choice.
- Debug and Alpha APK builds pass.
- Installed the Debug build on the existing Samuel emulator without clearing app data.
- `plus-before.png` and `longpress-before.png` show the original UI.
- Each theme has a `*-plus.png` and `*-share.png`: light, dark, black, sepia.
- Runtime checks assert that the plus button's vertical center matches the filter selector within two pixels, tap it to open Add site, then long-press a story to open Android's Share chooser. No share recipient is selected.
- Returned the emulator to sepia. Physical Samsung was not attached; its Alpha installation remains pending.
