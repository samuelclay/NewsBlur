# Android 15.0.2 open testing release

- Version: `15.0.2` / version code `287`; package: `com.newsblur`.
- Source and pushed tag: `3840275b699749a2586ac183564981e822c743e4`, `Android_15.0.2`.
- Branch: `android-add-discover-sites`. Builds on the submitted 15.0.1 release.
- [Release notes](en-US.txt): 360 characters excluding the final newline.

## Story long-press regression

[Forum report #13837](https://forum.newsblur.com/t/android-restore-mark-older-newer-read-options-for-long-press/13837/1) described losing the older/newer read actions after the gesture update. The actions remained in the context menu, but the new default opened Share instead.

Restored the default story long press to Menu in both the preference repository and Settings UI state. Explicitly selected Share, Ask AI, and other actions remain unchanged. Existing menu ordering and arrows follow Newest/Oldest sorting. Read-range actions use the selected story timestamp and current feed/folder/all-sites scope, including the selected story as the web does. Existing confirmation settings and exclusions for unsupported special lists remain in effect.

## Validation

- The preference regression failed before the fix, then all 11 focused preference/menu tests passed. Tests cover explicit preference preservation, actual menu resources, feed/folder/all-sites scopes in both orders, and actual row menu callbacks with the timestamp in the correct older/newer argument.
- Full suite: 508 tests, zero failures/errors/skips. Signed release build, lint-vital, and optimization passed.
- Reproduced the Share sheet on the logged-in Pixel 5 API 35 emulator, then verified the restored menu in light, dark, black, and sepia, portrait and landscape. The attached physical phone was locked, so these follow-up UI checks used the existing emulator image and preserved its session.
- Verified both read-range confirmation dialogs and canceled them without bulk-changing the account's read state. Checked Oldest order reverses the action order/arrows. Sepia screenshots also cover the All Site Stories scope.
- Restored Light theme, unset long-press and range-confirmation preferences, mark-read-on-scroll, Newest sorting, and automatic rotation. No NewsBlur crash observed in the emulator crash buffer.
- [Screenshots](screenshots/) include the original Share regression, both sort orders, both confirmation dialogs, and all eight theme/orientation cases.

## Artifacts

- Build command: `:app:testDebugUnitTest :app:bundleRelease` with Android Studio's JBR and existing local signing configuration.
- JAR signature and ZIP integrity verified. Signing certificate SHA-256 matches previous Play releases: `5C:5E:93:50:3C:6A:C4:89:88:6A:29:BE:0C:28:6B:A6:04:82:E2:C2:5A:A6:D6:EF:56:84:FD:6E:8F:D7:C3:19`.
- Bundle SHA-256: `8bdaacfa6986329f52f3ada078730c1596dcdaf66deb2449972d746894862e74`; size: 11,527,072 bytes. ReTrace mapping is embedded.
- Archived `NewsBlur-15.0.2.aab`, `NewsBlur-15.0.2-mapping.txt`, and `NewsBlur-15.0.2-testing-notes.txt` in `~/Library/Mobile Documents/com~apple~CloudDocs/NewsBlur/Android/Builds/`.

## Store submission

Submitted September 17, 2026 to **Open testing**, at 100% of that track. Play accepted `287 (15.0.2)` with the embedded ReTrace mapping and no loss of supported devices. The only non-blocking warning recommends native debug symbols.

Play required restarting the pending 15.0.1 review to include this follow-up. After restarting, the publishing overview shows **Changes in review** with **15.0.2 — Start full rollout**, quick checks running, and managed publishing off. This records submission, not confirmed availability to testers. Production remains unchanged.

- [Publishing overview](https://play.google.com/console/u/3/developers/6280481402178293168/app/4972990522498280751/publishing)
- [Release review](https://play.google.com/console/u/3/developers/6280481402178293168/app/4972990522498280751/tracks/4698162496597079541/releases/100/review)
- [Submission screenshot](play-testing-submitted.png)
