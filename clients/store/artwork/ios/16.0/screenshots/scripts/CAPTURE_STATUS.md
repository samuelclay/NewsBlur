# Native capture checkpoint, 2026-10-16

All 21 iPad locales have four visually verified native stills and finalized raw footage. The iPad Pro 13-inch (M5), UDID `883650D4-245E-4265-84A5-97606867CB5B`, is shut down; its five preference files were restored and SHA-256 verified against `/tmp/newsblur-ipad-capture-resume-backup`. The task iPhone 18 Pro Max, UDID `011EB534-697E-4855-BACA-4D4C6E4E92EF`, is being resumed for its remaining 17 locales; its three preference files still matched `/tmp/newsblur-iphone-capture-resume-backup` before boot. Another task’s iPhone 17e remains untouched. No production account is used.

## Verified complete native groups

| Locale | iPhone | iPad |
| --- | --- | --- |
| English | Four stills and finalized raw video | Four stills and finalized raw video; story list refreshed at 3:38 PM |
| French | Four stills and finalized raw video, `bdb0a7fc6` | Four stills and finalized raw video, `4953ca956` |
| Arabic | Four stills and finalized raw video, `454438c1a` | Four stills and finalized raw video, `f790aeaef` |
| German | Four stills and finalized raw video, `aca5de841` | Four stills and finalized raw video, `4057de826` |
| Spanish | Pending | Four stills and finalized raw video, `da506fae3` |
| Hebrew | Four stills and finalized raw video, `c3977de10` | Four stills and finalized raw video, visually verified |
| Dutch | Pending | Four stills and finalized raw video, `08829b4f2` |
| Portuguese (Brazil) | Pending | Four stills and finalized raw video, `25f4e43a0` |
| Polish | Pending | Four stills and finalized raw video, `b7e702377` |
| Italian | Pending | Four stills and finalized raw video, refreshed in `44849203b` |
| Turkish | Pending | Four stills and finalized raw video, `4c95477a1` |
| Russian | Pending | Four stills and finalized raw video, `5be4f9107` |
| Ukrainian | Pending | Four stills and finalized raw video, `c52de3fb2` |
| Hindi | Pending | Four stills and finalized raw video, refreshed in `d28522135` |
| Indonesian | Pending | Four stills and finalized raw video, `c72ceee53` |
| Vietnamese | Pending | Four stills and finalized raw video, `c0b1d82c2` |
| Thai | Pending | Four stills and finalized raw video, `36d45eced` |
| Japanese | Pending | Four stills and finalized raw video, `8f19cc5d6` |
| Korean | Pending | Four stills and finalized raw video, `beb55c757` |
| Chinese (Simplified) | Pending | Four stills and finalized raw video, `dc9a0f474` |
| Chinese (Traditional) | Pending | Four stills and finalized raw video, `6a6f4b247` |

Canonical English stills are in `../captures/`. Localized native stills are in `../captures/localized/<locale>/`. Raw videos and checkpoints are in `../footage/<device>/` for English and `../footage/localized/<locale>/<device>/` for localized takes. Raw videos require editing and visual timing review before upload. Video time can diverge from wall-clock checkpoints when CoreSimulator stalls.

The earlier Hebrew iPhone attempt had a blank article through a bounded 90-second readiness check. A fresh simulator boot resolved the transient WebKit state; the replacement take now has four visually verified states and complete footage. Failed takes are preserved under `/tmp/newsblur-he-delayed-transition-take` and `/tmp/newsblur-he-reader-timeout-take`; rejected blank frames are under `/tmp/newsblur-he-rejected-stills`. Hebrew iPad rendered correctly and is complete. All iPad locales are complete. Sixteen iPhone locales remain, captured in serial groups of four on the existing target.

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
