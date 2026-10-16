# Cooking screenshot fixtures

Ten original, fictional editorial sources and twenty cooking articles for fresh NewsBlur marketing screenshots. Each source has two unread articles; four articles are initially saved. The app renders these through its normal native feed list, story grid, article reader, saved stories, and intelligence trainer. Source titles, author names, and article text are content, not interface translations.

The five food photographs are real photography, downloaded from the source images and visually inspected. `photo-sources.json` records the photographer, exact Unsplash page, exact downloaded rendition, and license URL for each photo. They are available under the [Unsplash License](https://unsplash.com/license), which permits commercial reuse. None is AI-generated. The names in `cooking.json` do not attribute these original demo articles to the photographers or to real publishers.

## Install and launch

The fixture is enabled only in a Debug simulator build with BOTH `-newsblur-ui-testing` and `-newsblur-marketing-cooking`. No changes to the application target's resources are needed. For capture builds, copy this entire directory to `NewsBlur.app/MarketingCooking` after building and before installing. Alternatively, `-newsblur-marketing-assets /absolute/path` selects a readable runtime directory containing `cooking.json` and `photos/`.

Use the `NewsBlur` scheme and the existing simulator selected by `run_ios.py list`. The project's Debug target does not currently define the Swift `DEBUG` compilation condition, so pass `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG` explicitly to the capture build's `xcodebuild` command along with `-configuration Debug`. Without that override, the fixture guard remains disabled and the ordinary Tech test dataset appears. Do not change release build settings.

Then launch through `run_ios.py`, with `IOS_LAUNCH_ARGUMENTS` containing:

```
-newsblur-ui-testing -newsblur-marketing-cooking -newsblur-ui-test-screen reader-folder-tech -newsblur-ui-test-story-titles-style experimental -newsblur-ui-test-theme light -ApplePersistenceIgnoreState YES -newsblur_language en
```

`reader-folder-tech` selects the Cooking folder when this dataset is active. Available capture states:

- `reader`: feed sidebar with ten cooking sources.
- `reader-folder-tech`: all twenty cooking articles.
- `reader-feed-swift`: Weeknight Kitchen, including the pasta recipe.
- `reader-story-swift-1`: the complete pesto pasta article.
- `cooking-saved`: four saved articles.

Story title style `experimental` selects the current card/grid presentation; `standard` selects the classic list. Theme values: `light`, `sepia`, `medium`, `dark`. Add `-newsblur-ui-test-fill-window` for full iPad window layouts. Set `-newsblur_language <supported code>` to capture native localized UI; article content remains English, as real feed content would.

Save/unsave, read/unread, classifier training, and extracted text responses stay in the fixture process. Photos render from local data and the image cache; no remote photo request is needed during capture. All fixture API requests are intercepted at `https://ui-test.newsblur.example`; unexpected endpoints fail instead of falling through to NewsBlur production. The account database is in memory and mutations reset on process restart.

The opted-in Debug simulator process also adds its fixture protocol to newly created default URL sessions. This is required for the independent offline-sync and thumbnail-download managers; registering a `URLProtocol` class globally does not cover those managers. Requests outside the fixture host retain their usual handling. The hook is absent from release builds and is never installed for ordinary UI tests or app launches.

Validation: an isolated Foundation probe confirmed that default-session requests for unread hashes and photo bytes are intercepted locally, while an unrelated HTTPS request follows normal networking. Restoring the configuration getter also restored ordinary default-session behavior. The cooking response contract checks all twenty unread hashes against their story responses. Fresh iPhone runtime captures confirmed that offline sync settles and story thumbnails render. Native iPad captures and navigation recording also render the sidebar, thumbnails, full articles, and saved stories with `standard` story-title style; use that style for iPad capture.

If an old idb companion cannot find SimulatorKit after an Xcode update, restart only the selected simulator's companion, then use `run_ios.py reconnect` with the corrected companion environment. The capture workstation's existing `/tmp/newsblur-idb-xcode/Developer` shim points its legacy PrivateFrameworks path at Xcode's SharedFrameworks. Use that `DEVELOPER_DIR` only for reconnecting idb; return to the normal environment for screenshots and other xcrun actions. `IOS_CAPTURE_CPU=0` disables profiling during `capture:<directory>` recordings. Keep one simulator running at a time and shut it down before restoring the backed-up preference files.

## Account isolation

The existing UI harness replaces the account database, but normal feed loading still writes standard preferences and shared extension preferences. Before using a simulator with an existing account, preserve BOTH its app data/preferences and its `group.com.newsblur.NewsBlur-Group` shared data/preferences. Restore both after the capture session. `run_ios.py restoreprefs:<plist>` restores the standard preference domain only. Do not treat it as a complete shared-container backup.

No production account is created or modified. The visible account name `Alex` belongs to this synthetic dataset. This folder is not automatically bundled into a release build.
