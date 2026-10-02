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

## Provider configuration and rollout

Both provider changes were submitted with explicit approval and verified as saved:

- Google project `newsblur`: web OAuth client **NewsBlur iOS sign-in backend**, with redirect `https://www.newsblur.com/api/social/google/callback`. The existing app audience is External and In production. Requests ask only for `openid email`.
- Apple Developer team `HR7P97SD72`: **Sign In with Apple** enabled as a primary capability for `com.newsblur.NewsBlur`. Native Apple sign-in uses that bundle ID as its token audience. The server currently accepts the production bundle ID as the Apple audience; Alpha Apple authentication has not been verified.

Google credentials are stored outside Git in `/srv/secrets-newsblur/keys/google-signin-client.json` (mode 0600) and the existing `/srv/secrets-newsblur/settings/common_settings.py`. The worktree's ignored `newsblur_web/local_settings.py` also has them. No credentials are embedded in the iOS application.

Before a production release, synchronize the updated common settings using the existing `web`/`celery_task` role `env` tasks: regular `make deploy` does not copy this secrets file. Deploy the web code and migration `profile.0032_socialidentity` through the scoped web deployment; deploy task code as well because the shared profile model changed. Confirm the deployed image provides `PyJWT[crypto]` from `config/requirements.txt`. Refresh Apple provisioning profiles for the new entitlement before archiving a device build.

The production callback is not deployed. A real Apple/Google round trip on a signed device, production cookie/session handoff, and a real asynchronous OPML import remain release verification steps. The tests and screenshots above do not claim those flows have run against production.
