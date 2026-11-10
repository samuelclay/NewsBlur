# Android 15.1

- Version: `15.1`, version code `291`.
- Release tag: `Android_15.1` on the version bump commit.
- Built with Android Studio's JDK and the existing NewsBlur release signing key.
- `:app:testDebugUnitTest :app:bundleRelease` passed: 814 tests, no failures or skipped tests.
- Signed AAB ZIP integrity and JAR signature verified.
- Signing certificate SHA-256: `5C:5E:93:50:3C:6A:C4:89:88:6A:29:BE:0C:28:6B:A6:04:82:E2:C2:5A:A6:D6:EF:56:84:FD:6E:8F:D7:C3:19`.
- AAB SHA-256: `d30696cdbb8206e3d21b96824f7a7df19abbbc0729f802b16540100a56de46f2`.
- Bundle, mapping, and release notes archived under `~/Library/Mobile Documents/com~apple~CloudDocs/NewsBlur/Android/Builds/NewsBlur-15.1*`.
- Production rollout target: 100%, with managed publishing off.

## Play submission

Submitted on October 9, 2026. Play's Publishing overview confirms `Changes in review` for `15.1`, with `Start full rollout` and managed publishing off. Automated quick checks were still running when this state was recorded; the release is not yet confirmed approved or publicly available.

- Production release: `95`.
- Release source: `44971474c2deabf027ff191b94017edeb441d86a`.
- Play accepted the uploaded bundle as `291 (15.1)` with its embedded ReTrace mapping file.
- No blocking validation errors. Play reports the existing recommendation to upload native debug symbols.
- Review URL: https://play.google.com/console/u/3/developers/6280481402178293168/app/4972990522498280751/tracks/4699046005160626232/releases/95/review
