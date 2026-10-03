# Android first-time experience

Branch `Android-FTUX` ports the account and feed setup experience from `iOS-FTUX` at `254090b9d`. NB Alpha (`com.newsblur.alpha`) is used for physical-device checks; the installed production app is untouched.

## Design progression reviewed

| iOS commit | Decision carried into Android |
| --- | --- |
| `8412469b5` | Inline email/username/password, Apple and Google, last-used provider, OPML and feed bundles. |
| `f414c2bb6` | Keep reader loading while feed additions and the first full refresh are pending. |
| `9c2b7859e` | Preserve ownership of tablet feed navigation; setup is a separate full-window activity. |
| `2a2f8bed9` | Reopen import and bundles from the main menu. |
| `90a88c7c3` | Adaptive import panel and one search field for interests and sites, with destination folders. |
| `fc0a20b3d` | Leave Android's existing native feed drawer navigation intact. |
| `fe0921632` | Batch known feed IDs, preserve folder paths, handle per-feed failures. |
| `46f19fb14` | Respect available window width; Android retains its existing tablet navigation and embedding policy. |
| `484615acc` | Progressive source loading, audited icons, English/recent stories, stable selection and folder edits, quiet completion with actual recap and community links. |
| `208654f72` | Check tablet portrait and landscape through setup transitions. |
| `da96460ea` | Bind background work to a login generation; verify account ownership before deletion. |
| `6367aefe2` | Apple reauthentication and revocation with manual disconnection guidance on failure. |
| `254090b9d` | Preserve the separate, strict Apple code-exchange token validator. |

The iOS palette is centralized in `SetupPalette.kt`: light, dark (iOS medium), black (iOS dark), and sepia. Platform fonts, icons, file picker, and browser presentation use Android equivalents. The audited feed catalog and exclusions are regenerated with `ruby clients/android/tools/export_onboarding_catalog.rb` from the repository root.

## Verification

- Samsung S22 (`SM-S901U1`) and Galaxy Tab A8 (`SM-X200`), using the existing attached devices.
- Live production catalog and bundle browsing in NB Alpha, without adding feeds to the production account.
- Phone and tablet catalog/bundle screenshots in light, dark, black, and sepia. Tablet rotation preserves the current bundle.
- A 1.3x font-scale check on the S22 keeps the interest heading and search field readable by stacking them. Device rotation and font settings were restored after testing.
- Whole-card deselection changes the selected count; an edited folder appears in the action title. Site search returns real feed icons and metadata.
- Disposable local account: native sign-in, automatic empty-account setup, valid OPML upload, nested-folder completion recap, and password-confirmed account deletion.
- Empty OPML files produce an inline message beside the import control before any upload.
- OPML processing was explicitly run in the local Docker container because this worktree has no Celery worker. The completion email was mocked out. The imported server folder was `FTUX Test ▸ Nested`, containing one feed.
- Android: 729 unit tests passed. These cover account changes during capability probing, ambiguous batch errors, partial failure retry, OPML bounds/entities/nesting, progressive selections, empty-array/object server responses, and keeping loading active until the refreshed feed cursor is displayed.
- Backend: all 42 `apps.api.test_social_auth` tests passed, including signed Apple web token audience/nonce and replay checks, fixed callback destinations, and password/social deletion guards.
- Alpha APK builds and production debug Kotlin compilation pass. No instrumentation APK was installed on either shared device.

Representative evidence:

| Phone | Tablet |
| --- | --- |
| [Light catalog](s22-catalog-light.png) | [Light catalog](tablet-catalog-light.png) |
| [Dark bundle](s22-bundle-dark.png) | [Dark bundle](tablet-bundle-dark.png) |
| [Black catalog](s22-catalog-black.png) | [Black catalog](tablet-catalog-black.png) |
| [Sepia bundle](s22-bundle-sepia.png) | [Sepia bundle](tablet-bundle-sepia.png) |
| [Edited folder and deselection](s22-bundle-edited-selection.png) | [Portrait bundle](tablet-bundle-portrait.png) |
| [Site search](s22-search-light.png) | [Local account deletion](tablet-account-deleted.png) |

Screenshots were captured during implementation; the final header also adds the iOS search outline and removes its placeholder. See [large text](s22-large-text.png), [final tablet header](tablet-catalog-black-final.png), [invalid OPML](tablet-invalid-opml.png), [import recap](tablet-opml-recap.png), and [sign-in](tablet-signin.png).

## Provider setup before release

The Android provider implementation and backend protocol are present, but real Apple and Google round trips have not been verified. These routes have not been deployed by this task.

Apple browser sign-in requires an Apple Services ID associated with the NewsBlur primary App ID, domain `www.newsblur.com`, and return URL `https://www.newsblur.com/api/social/apple/callback`. Set `SOCIAL_APPLE_WEB_CLIENT_ID` to that Services ID outside the repository. The existing Apple team ID, key ID, and private-key path are also needed for deletion authorization-code exchange and revocation. Native iOS audiences remain separate.

Google uses the existing server OAuth client and `https://www.newsblur.com/api/social/google/callback`. Deploy the platform-aware backend before testing Android: production callbacks use `newsblur-auth-android://complete`, and NB Alpha uses `newsblur-auth-android-alpha://complete`. Each ticket is bound to the app-generated verifier. Test sign-in, username selection, linking, cancellation, and provider-backed deletion after configuration/deployment.

No Android version bump, Play upload, backend deployment, or provider-console configuration is included in this FTUX work.
