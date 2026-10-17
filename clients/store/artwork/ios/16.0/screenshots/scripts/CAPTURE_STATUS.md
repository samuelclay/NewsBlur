# Native capture checkpoint, 2026-10-16

All 21 supported locales now have four visually verified native iPhone screenshots and four native iPad screenshots: 168 stills total. All 21 iPad locales and six iPhone locales also have finalized raw footage. The last 15 iPhone groups were captured as stills first on an isolated iPhone 18 Pro Max, `7DC67F2D-270D-4798-917A-105C5BCB00DE` (NewsBlur Store Capture 16), running iOS 27.0. This target reused the verified NewsBlur 16.0 (343) app without rebuilding. All 84 iPhone PNGs have native dimensions 1320 × 2868; all 84 iPad PNGs are 2064 × 2752. Every new group passed visual review for localized interface text, loaded thumbnails and article, the actual four-item Saved list, and absence of foreign-app status-bar breadcrumbs. Raw footage for the last 15 iPhone locales remains pending.

The original iPhone remained subject to concurrent Turn Touch use even after reservation, so no further actions or preference restoration are performed there. Its original backup remains at `/tmp/newsblur-iphone-capture-resume-backup`. The previous iPad capture target was shut down and its five preferences restored and SHA-256 verified before another task reused it. Other tasks’ devices remain untouched. The new capture target had no pre-existing account or preferences. It was shut down immediately after capture; the wrapper inventory confirmed Shutdown. No production account is used.

## Verified complete native groups

| Locale | iPhone | iPad |
| --- | --- | --- |
| English | Four stills and finalized raw video | Four stills and finalized raw video; story list refreshed at 3:38 PM |
| French | Four stills and finalized raw video, `bdb0a7fc6` | Four stills and finalized raw video, `4953ca956` |
| Arabic | Four stills and finalized raw video, `454438c1a` | Four stills and finalized raw video, `f790aeaef` |
| German | Four stills and finalized raw video, `aca5de841` | Four stills and finalized raw video, `4057de826` |
| Spanish | Four stills and finalized raw video, `b7d1d7782` | Four stills and finalized raw video, `da506fae3` |
| Hebrew | Four stills and finalized raw video, `c3977de10` | Four stills and finalized raw video, visually verified |
| Dutch | Four stills, `0855bd9f8`; video pending | Four stills and finalized raw video, `08829b4f2` |
| Portuguese (Brazil) | Four stills, `f02b033d5`; video pending | Four stills and finalized raw video, `25f4e43a0` |
| Polish | Four stills, `5986d0eb3`; video pending | Four stills and finalized raw video, `b7e702377` |
| Italian | Four stills, `5d7810d8e`; video pending | Four stills and finalized raw video, refreshed in `44849203b` |
| Turkish | Four stills, `f3bb9758d`; video pending | Four stills and finalized raw video, `4c95477a1` |
| Russian | Four stills, `d88a93a55`; video pending | Four stills and finalized raw video, `5be4f9107` |
| Ukrainian | Four stills, `1348cdb8b`; video pending | Four stills and finalized raw video, `c52de3fb2` |
| Hindi | Four stills, `7d02ec47c`; video pending | Four stills and finalized raw video, refreshed in `d28522135` |
| Indonesian | Four stills, `45b79f41a`; video pending | Four stills and finalized raw video, `c72ceee53` |
| Vietnamese | Four stills, `9976831e3`; video pending | Four stills and finalized raw video, `c0b1d82c2` |
| Thai | Four stills, `f7ab5be38`; video pending | Four stills and finalized raw video, `36d45eced` |
| Japanese | Four stills, `ec1cf4e64`; video pending | Four stills and finalized raw video, `8f19cc5d6` |
| Korean | Four stills, `726ec39b0`; video pending | Four stills and finalized raw video, `beb55c757` |
| Chinese (Simplified) | Four stills, `aeef40459`; video pending | Four stills and finalized raw video, `dc9a0f474` |
| Chinese (Traditional) | Four stills, `f9bbb489e`; video pending | Four stills and finalized raw video, `6a6f4b247` |

Canonical English stills are in `../captures/`. Localized native stills are in `../captures/localized/<locale>/`. Raw videos and checkpoints are in `../footage/<device>/` for English and `../footage/localized/<locale>/<device>/` for localized takes. Raw videos require editing and visual timing review before upload. Video time can diverge from wall-clock checkpoints when CoreSimulator stalls.

The earlier Hebrew iPhone attempt had a blank article through a bounded 90-second readiness check. The replacement take succeeded after a fresh simulator boot and now has four visually verified states and complete footage. Failed takes are preserved under `/tmp/newsblur-he-delayed-transition-take` and `/tmp/newsblur-he-reader-timeout-take`; rejected blank frames are under `/tmp/newsblur-he-rejected-stills`. Hebrew iPad rendered correctly and is complete. All iPad locales are complete. The completed 15-locale stills-only batch covers: Italian, Dutch, Brazilian Portuguese, Polish, Turkish, Russian, Ukrainian, Hindi, Indonesian, Vietnamese, Thai, Japanese, Korean, simplified Chinese, and traditional Chinese.

The native Arabic/Hebrew Saved title has an existing clock-icon overlap at its left end; captures preserve the actual app UI. This is separate from the fixed capture-coordinate error: RTL reader Back uses x420, while the story-list All button requires x390.

An Italian iPad attempt missed the sidebar tap during the reader-collapse transition. Its readiness gate rejected the incomplete sequence; the failed raw take is preserved at `/tmp/newsblur-it-sidebar-timeout-take`. The script now waits for the story list to become accessible before opening the sidebar. Its next take completed, but initial split-reader text remained at the app's smaller first-load size. That take is preserved at `/tmp/newsblur-it-small-text-take`. A native expand/collapse cycle now normalizes the initial reader layout; the replacement Italian take and all four stills passed visual review. No pixels or native controls are retouched.

## Reproduction and readiness

Run from repository root after backing up simulator app and shared preferences. Use only `clients/ios/run_ios.py` for simulator interaction, one capture simulator at a time, and restore preferences after shutdown. Keep preview encoding out of active recording windows.

```sh
ruby clients/store/artwork/ios/16.0/screenshots/scripts/capture_locales.rb ipad he
```

The script uses standard story layout and the DEBUG simulator cooking fixture. It refuses to overwrite an existing recording. Both device branches wait for actual accessibility state and loaded photo pixels before capturing. `run_ios.py waitphoto` compiles the small macOS `ScreenshotReadiness.swift` helper once into the temporary directory; it reads captured pixels without changing images. The helper rejected the blank Hebrew article at 0% colored pixels and accepted a loaded reader at 64%. Each wait is bounded to 90 seconds. Visual review still checks all four states and every visible thumbnail before a group is marked verified.

All app builds are reused. A stale idb HID connection after simulator shutdown may require reconnecting only this target’s companion with the existing `/tmp/newsblur-idb-xcode/Developer` shim; normal simulator commands use the regular Xcode environment.

Final localized rendering, App Preview editing, store upload, and resubmission are separate workstreams owned by the coordinator and preview agent.

Hindi exposed an additional native transition: selecting the already-open Cooking folder reloaded the WebKit reader at a smaller initial size. The capture now closes the sidebar with its native button, preserving the normalized reader. The replacement Hindi take passed all four visual checks. Indonesian Saved retains the pasta article with four saved items; its final decoded frame is fully loaded and can be held explicitly by the preview editor.

The first Spanish iPhone take stalled after opening Cooking: a later live frame showed a partial navigation animation with a gray placeholder, and accessibility returned an empty application. Reconnecting the target HID companion alone did not recover it. The rejected take is preserved at `/tmp/newsblur-es-input-timeout-take`; the same simulator was shut down, its three preferences restored and verified, then booted for a bounded retry. No app rebuild or animation speed change was made.

Spanish then completed successfully, but Italian failed its first story-list readiness check. A fresh screenshot from the same explicit UDID showed Turn Touch's Language screen with a return-to-NewsBlur indicator. Evidence is saved in `../evidence/iphone18-cross-task-interference.png`. This proves concurrent use of the capture device; it also means the earlier transition stalls cannot confidently be attributed solely to resource pressure. All simulator actions stopped immediately. The rejected Italian take is preserved outside canonical assets at `/tmp/newsblur-it-cross-task-interference-take`. That rejected take is not promoted. The later isolated-target Italian stills replace it.

After the user reserved the original target, iOS retained a return-to-Turn-Touch status-bar breadcrumb. A native Home gesture followed by launching NewsBlur cleared it, verified with a fresh frame. Three otherwise complete takes were rejected and preserved under `/tmp/newsblur-return-breadcrumb-takes`; the isolated batch replaced them. Alternate iPhone17 Pro Max C155B5E4 was briefly booted before the reservation reply arrived, then immediately shut down without installing or launching an app. Its original NewsBlur preferences were restored and verified; full prior app/shared data and binary are backed up at `/tmp/newsblur-iphone17max-capture-backup`. No alternate captures are used.

## Isolated stills capture

The completed command was `NEWSBLUR_CAPTURE_UDID=7DC67F2D-270D-4798-917A-105C5BCB00DE ruby clients/store/artwork/ios/16.0/screenshots/scripts/capture_locales.rb --stills-only iphone it nl pt-BR pl tr ru uk hi id vi th ja ko zh-Hans zh-Hant`. The script keeps accessibility/photo readiness gates and native settled screens, omits recording and five-second video holds, and uses the harness default with animations disabled. It does not edit screenshot pixels. The `run_ios.py create` action was added only to create this explicitly authorized isolated target after no usable capture simulator remained. The first HID connection needed the existing SimulatorKit compatibility shim for this target’s companion; normal wrapper commands use the regular Xcode environment.
