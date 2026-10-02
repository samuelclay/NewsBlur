# iOS first-time experience

Implemented in the `iOS-FTUX` worktree. These changes have not been deployed or submitted to the App Store.

## Screens

| Account | Import | Discover | Bundle | Complete |
| --- | --- | --- | --- | --- |
| [Create account](onboarding-account.png) | [Import OPML](onboarding-import-light.png) | [Interests](onboarding-discovery-light.png) | [Choose feeds](onboarding-bundle-light.png) | [Community](onboarding-complete-light.png) |

[Returning user and last-used badge](onboarding-last-used.png). The first page now combines OPML import and discovery; the import and discovery screenshots show different scroll positions of that same page. Bundle and completion screenshots cover light, sepia, medium and dark themes. Screenshots use isolated feed fixtures.

`OnboardingAccountViewController.swift` reuses the original Metal wave shader, glowing 120pt logo, Gotham title, gold Chronicle tagline, frosted glass and gold action button. The renderer pauses when hidden, inactive or Reduce Motion is enabled. It presents Apple and Google sign-in above the visible email, username and password fields. Returning users get username/email and password, with the last successful method badged. Social signup asks for a username. Matching an existing account by verified email requires that account's password before linking.

`OnboardingViewController.swift` replaces the old welcome/category/friends sequence with a combined import/discovery page followed by completion. OPML uses the existing `/import/opml_upload` endpoint and preserves its queued-import behavior. Interest bundles use the current Discover catalog, with up to three websites, newsletters, YouTube channels, Reddit feeds and podcasts per interest. Interest cards show actual feed icons. Bundle sheets reuse `DiscoverFeedCardView`, including icons, story titles, excerpts and image thumbnails. Users can deselect sources and name the destination folder. Adding uses `/reader/add_url` with `new_folder` and an exact root `folder_path`, so retries reuse the folder and retain only failed selections. Full Add and Discover search remains accessible. Done closes immediately during loading or subscription work. A retained serial queue snapshots each destination and selection, guards against account changes, and keeps failed additions available for retry. It continues when the sheet or onboarding is dismissed while the app remains running.

Feeds refresh when entering completion, tapping Start Reading, accepting an import and finishing queued additions. Completion links to the forum, Samuel Clay on X and NewsBlur on X. Completing setup persists a per-account preference so an intentionally empty reader does not reopen onboarding.

## Verification

- 15 backend tests pass, including real PostgreSQL account creation, authenticated sessions and password-proven account linking. External email/queue side effects are stubbed. Signed-token tests reject wrong issuer, audience, nonce, expiration, signature and unverified email; state/tickets are single use and bound to the initiating app's verifier.
- 6 iOS unit tests pass: original Metal background/lifecycle, immediate queue return with folder snapshots and refresh callbacks, mixed-source bundles, partial subscription retry and folder-creation parameters, OPML multipart content/queued response, invalid-file rejection and authentication continuation.
- 4 iOS UI tests pass on the existing iPhone 17e simulator (`3AD72704-02E5-4B1D-AA90-02413F046991`). They exercise visible signup fields, returning-user mode, the last-used badge, Files picker cancellation, bundle addition and completion across all four themes, immediate Done during slow previews, and finishing setup while additions remain queued. Network mutations use isolated fixtures.
- The real local Discover API returned catalog categories and YouTube feed URLs with the expected schema.
- NB Alpha was rebuilt, installed and launched on ClayPad Air; the app process was confirmed running with existing data preserved. Device Hub screen capture timed out, so visual proof here comes from the simulator.
- `git diff --check` passes.

Commands from the worktree root:

```sh
docker exec -t newsblur_web_iOS-FTUX python manage.py test apps.api.test_social_auth --settings=newsblur_web.test_settings --noinput -v 1
python3 clients/ios/run_ios.py list
xcodebuild -project clients/ios/NewsBlur.xcodeproj -scheme NewsBlur -configuration Debug \
  -destination 'id=3AD72704-02E5-4B1D-AA90-02413F046991' \
  -derivedDataPath /tmp/newsblur-ios-ftux-build -parallel-testing-enabled NO \
  -only-testing:NewsBlurTests/Test_Onboarding \
  -only-testing:NewsBlurUITests/Test_OnboardingUI test
```

The original background regression failed in `/tmp/newsblur-ftux-chrome-red.log`, and Done-while-loading failed in `/tmp/newsblur-ftux-done-red.log`. The updated unit tests, account UI and slow-network navigation tests pass in `/tmp/newsblur-ftux-restored.xcresult`. That run exposed an invalid accessibility assertion for decorative thumbnails; the images were visibly rendered in its screenshots. The corrected theme run is `/tmp/newsblur-ftux-discovery-final.xcresult`. Backend output is `/tmp/newsblur-ftux-backend-database.log`.

## Loading feeds after setup

`OnboardingViewController.swift` retains a shared loading state across queued subscriptions, OPML upload and the final feed refresh. Completion shows a spinner labeled “Loading your feeds…” above the enabled Start Reading button. After dismissal, the same state appears in the feed list's existing `SyncNotifierView`, with navigation still available. It ends after the latest feed response renders or fails. Failed additions remain retryable; a failed final refresh preserves the usual Offline/error presentation.

`FeedsObjCViewController.m` now rejects older feed-list responses, including their asynchronous database and rendering work. A slower partial response can no longer replace a newer complete list. Offline cache publication observes the same request generation.

| Completion while loading | Feed list while loading | Final refresh complete |
| --- | --- | --- |
| [Visible spinner and Start Reading](onboarding-loading-final.png) | [Nonblocking feed-list spinner](onboarding-loading-reader.png) | [Spinner cleared](onboarding-loading-reader-finished.png) |

The slow-additions UI regression first failed twice in `/tmp/newsblur-loading-red.xcresult`, and the real `fetchFeedList` request-order regression failed in `/tmp/newsblur-loading-race-red.log` by applying `[complete, partial]`. All 9 onboarding unit tests pass in `/tmp/newsblur-loading-final.xcresult`, including pending-work/final-refresh lifetime, all additions failing, and final refresh error ordering. The final UI run passes in `/tmp/newsblur-loading-footer.xcresult`: the loading label is visibly reachable on completion, Start Reading remains enabled, progress survives into the feed list, and disappears after the queued work and final refresh finish. These screenshots and delayed responses use isolated fixtures on the existing iPhone 17e simulator.

## iPad interactive edge reveal

`FeedDetailObjCViewController.m` attaches the iPad feed-list edge gesture to the split viewport and gives it priority over competing navigation gestures in intermediate split containers. The prior gesture could begin recognition without ever receiving a drag callback on iOS 27. The existing interactive reveal now follows the edge drag, remains available after cancellation, and preserves configured story-row actions. A cancelled gesture never commits the sidebar open, even after crossing the distance or velocity threshold. Hidden or covered title panes cannot use the viewport gesture.

[Before the edge drag](ipad-edge-before.png), [feeds revealed](ipad-edge-revealed.png), and [Two Columns with Save preserved](ipad-edge-save-preserved.png) show isolated fixtures on the iOS 27 iPad Air simulator (`F1931FFE-8117-4164-B71D-C91AF30CEF47`). The four-case UI matrix passes in `/tmp/newsblur-ipad27-root-priority.log`: Auto and Two Columns, each with Back and Save, including a short cancelled edge followed by a completed reveal. Three hosted gesture tests and a further UI test for row Back after a cancelled edge pass in `/tmp/newsblur-ipad27-verified.xcresult`. The hosted tests cover continuous drag position, forced cancellation, gesture priority, and existing Duo behavior. Both existing iPhone edge/full-row Back regressions pass in `/tmp/newsblur-ftux-phone-gestures.xcresult`.

NB Alpha is installed and launches on the unlocked ClayPad Air. Physical automation initially timed out while enabling automation; subsequent checks below ran successfully.

## Reopening import on an existing account

The feed-list gear menu now includes **Import or upload sites**, matching the web Manage menu, above Mute Sites and Organize Sites. It reopens the combined OPML import and interest bundles screen without changing accounts or resetting subscriptions. The completion flag only controls automatic presentation, so this menu remains available after completing setup.

[Import menu](import-menu.png) shows the entry on the existing iPhone simulator. `Test_OnboardingUI.test_existingAccountCanReopenImportAndBundles` passes in `/tmp/newsblur-ftux-import-menu.xcresult`: it opens the real settings menu, opens and cancels the Files picker, verifies bundles, completes setup, checks an existing subscription remains, and repeats without relaunching or creating an account. The updated NB Alpha build succeeds in `/tmp/newsblur-ftux-claypad-import-menu.log` and is installed and running on ClayPad Air.

The same reopen-and-finish test also passes on the existing iOS 27 iPad Air simulator in `/tmp/newsblur-ftux-ipad-import-menu.xcresult`, covering the iPad popover dismissal and presentation handoff.

## Import and discovery layout refinement, October 2

[ClayPad with live feed icons](redesigned-import-claypad.png) and [dark iPad simulator](redesigned-import-dark.png) show the revised page. The ClayPad capture is normalized to upright portrait. The import description and button share one row on iPad and wrap together on narrow screens. The marketing headline, diagonal arrows, second search control, and redundant Skip action are removed. Cards use two columns on iPad, one on narrow screens, equal scaled heights, and icons beside their titles. Feed icons appear progressively as each source arrives, with placeholders during initial loading.

One search field filters interests and searches sites through the existing Discover autocomplete service. Results reuse `DiscoverFeedCardView`; adding uses the retained onboarding queue and exact folder paths, including on retry. The field has a VoiceOver label and clear action.

Validation: ten hosted onboarding tests and iPhone UI tests pass in `/tmp/newsblur-ftux-redesign.xcresult`; the final nested-folder retry and search checks pass in `/tmp/newsblur-ftux-redesign-final-search.xcresult`. Import, shared bundle previews, completion, equal card heights, and two-column layout pass across all four themes on iPad in `/tmp/newsblur-ftux-redesign-ipad-final.xcresult`. The first iPad run exceeded the Files picker's five-second startup allowance; the test now allows fifteen seconds. The signed-in ClayPad menu and live icon check passes in `/tmp/newsblur-claypad-redesign-final.xcresult`, with the final NB Alpha installed.

The reported cold-launch edge failure remains unreproduced. Stronger tests now exercise the very first drag without the cancelled warm-up used by earlier coverage: Auto and Two Columns on iPad simulator, after closing import, and directly from All Site Stories on physical ClayPad. All pass. [ClayPad before the first edge](claypad-first-edge-before.png) and [after](claypad-first-edge-after.png) come from `/tmp/newsblur-claypad-initial-edge-before.xcresult`. Gesture production code was not changed in this refinement. XCTest waits for launch idle; a gesture during the earliest startup transition remains unverified.

## Provider configuration and rollout

Both provider changes were submitted with explicit approval and verified as saved:

- Google project `newsblur`: web OAuth client **NewsBlur iOS sign-in backend**, with redirect `https://www.newsblur.com/api/social/google/callback`. The existing app audience is External and In production. Requests ask only for `openid email`.
- Apple Developer team `HR7P97SD72`: **Sign In with Apple** enabled as a primary capability for `com.newsblur.NewsBlur`. Native Apple sign-in uses that bundle ID as its token audience. The server currently accepts the production bundle ID as the Apple audience; Alpha Apple authentication has not been verified.

Google credentials are stored outside Git in `/srv/secrets-newsblur/keys/google-signin-client.json` (mode 0600) and the existing `/srv/secrets-newsblur/settings/common_settings.py`. The worktree's ignored `newsblur_web/local_settings.py` also has them. No credentials are embedded in the iOS application.

Before a production release, synchronize the updated common settings using the existing `web`/`celery_task` role `env` tasks: regular `make deploy` does not copy this secrets file. Deploy the web code and migration `profile.0032_socialidentity` through the scoped web deployment; deploy task code as well because the shared profile model changed. Confirm the deployed image provides `PyJWT[crypto]` from `config/requirements.txt`. Refresh Apple provisioning profiles for the new entitlement before archiving a device build.

The production callback is not deployed. A real Apple/Google round trip on a signed device, production cookie/session handoff, and a real asynchronous OPML import remain release verification steps. The tests and screenshots above do not claim those flows have run against production.
