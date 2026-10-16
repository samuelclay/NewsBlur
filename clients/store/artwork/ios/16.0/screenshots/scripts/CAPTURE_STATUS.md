# Native capture checkpoint, 2026-10-16

The existing iPad Pro 13-inch (M5), UDID `883650D4-245E-4265-84A5-97606867CB5B`, is active for localized capture. The capture iPhone 18 Pro Max is shut down; its three preference files were restored and SHA-256 verified against `/tmp/newsblur-iphone-capture-resume-backup`. The iPad has a fresh five-file backup at `/tmp/newsblur-ipad-capture-resume-backup` to restore after shutdown. Another task’s iPhone 17e is untouched. No production account is used.

## Verified complete native groups

| Locale | iPhone | iPad |
| --- | --- | --- |
| English | Four stills and finalized raw video | Four stills and finalized raw video; story list refreshed at 3:38 PM |
| French | Four stills and finalized raw video, `bdb0a7fc6` | Four stills and finalized raw video, `4953ca956` |
| Arabic | Four stills and finalized raw video, `454438c1a` | Four stills and finalized raw video, `f790aeaef` |
| German | Four stills and finalized raw video, `aca5de841` | Pending |
| Hebrew | Incomplete article capture | Four stills and finalized raw video, visually verified |

Canonical English stills are in `../captures/`. Localized native stills are in `../captures/localized/<locale>/`. Raw videos and checkpoints are in `../footage/<device>/` for English and `../footage/localized/<locale>/<device>/` for localized takes. Raw videos require editing and visual timing review before upload. Video time can diverge from wall-clock checkpoints when CoreSimulator stalls.

Hebrew iPhone has valid feed/story/Saved states but its article remained blank through a bounded 90-second readiness check. It is incomplete and not promoted. Failed takes are preserved under `/tmp/newsblur-he-delayed-transition-take` and `/tmp/newsblur-he-reader-timeout-take`; rejected blank frames are under `/tmp/newsblur-he-rejected-stills`. Hebrew iPad rendered correctly and is complete. The remaining iPad locales are next, in serial groups of three or four. Other supported locales remain pending.

The native Arabic/Hebrew Saved title has an existing clock-icon overlap at its left end; captures preserve the actual app UI. This is separate from the fixed capture-coordinate error: RTL reader Back uses x420, while the story-list All button requires x390.

## Reproduction and readiness

Run from repository root after backing up simulator app and shared preferences. Use only `clients/ios/run_ios.py` for simulator interaction, one capture simulator at a time, and restore preferences after shutdown. Keep preview encoding out of active recording windows.

```sh
ruby clients/store/artwork/ios/16.0/screenshots/scripts/capture_locales.rb ipad he
```

The script uses standard story layout and the DEBUG simulator cooking fixture. It refuses to overwrite an existing recording. Both device branches wait for actual accessibility state and loaded photo pixels before capturing. `run_ios.py waitphoto` compiles the small macOS `ScreenshotReadiness.swift` helper once into the temporary directory; it reads captured pixels without changing images. The helper rejected the blank Hebrew article at 0% colored pixels and accepted a loaded reader at 64%. Each wait is bounded to 90 seconds. Visual review still checks all four states and every visible thumbnail before a group is marked verified.

All app builds are reused. A stale idb HID connection after simulator shutdown may require reconnecting only this target’s companion with the existing `/tmp/newsblur-idb-xcode/Developer` shim; normal simulator commands use the regular Xcode environment.

Final localized rendering, App Preview editing, store upload, and resubmission are separate workstreams owned by the coordinator and preview agent.
