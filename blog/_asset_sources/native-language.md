# Native language support screenshots

Captured October 14, 2026 for `2026-10-14-newsblur-in-your-language.md`.

- `native-language-reader-ja.jpg`: the web reader on staging (i18n branch) in Japanese, with Ars Technica's "The Internet's undersea backbone" story open. Captured at 1x through Claude in Chrome with samuel's account language set to Japanese, then set back afterward. The staff-only "Briefing Admin" sidebar row was hidden for the shot because readers never see it.
- `native-language-welcome-fr.png`: the signed-out home page on staging, captured at 2x in headless Chromium with a French Accept-Language and a fresh profile, cropped to the top 1620px. The language menu at the top left reads "Auto · Français".
- `native-language-dialog.png`: the one-time language dialog in German and English, from the i18n worktree's local web stack in headless Chromium at 2x (Whitney is unavailable there, so it uses the fallback font), cropped around the dialog.
- `ios-native-language-preferences.png`: iOS Preferences in Spanish on the iPhone 17e simulator, opened through the `preferences` UI-test launch route with `-newsblur_language es`. The app's defaults were backed up and restored afterward.
- `ios-native-language-feeds.png`: the iOS feed list in Spanish on the same simulator, logged in as samuel.
- `android-native-language-settings.png` and `android-native-language-menu.png`: NewsBlur Alpha on Sam's Galaxy S22 in German, chosen through Settings > Language, showing Settings and the Engadget feed menu. The account language was set back to Automatic afterward.

All images are unmodified captures apart from cropping. Mobile images use the existing `mobile-release-phone.html` include and its iPhone 17 and Galaxy S22 frames.
