# Native capture checkpoint, 2026-10-16

Capture resumed after host recovery. Our iPhone 18 Pro Max is active for localized capture; another task’s iPhone 17e is untouched. A fresh three-file preference backup is at `/tmp/newsblur-iphone-capture-resume-backup`. Before this resumed batch, all capture simulators were shut down. The iPhone's three preference files were restored and SHA-256 verified against `/tmp/newsblur-iphone-capture-final-backup`; the iPad's five files were restored from `/tmp/newsblur-ipad-capture-final-backup`. No production account was used.

English has four verified iPhone and four verified iPad screenshots in `../captures/`. The iPhone story list retains the earlier experimental-layout capture because it has all five photo thumbnails. The refreshed iPhone feed list, article reader, and Saved Stories use standard layout; standard avoids clipped Saved Stories margins. iPad uses standard throughout. These are unretouched native captures of actual supported layouts.

Raw English footage is finalized in `../footage/iphone/scroll.mp4` (116.36 seconds) and `../footage/ipad/scroll.mp4` (27.75 seconds). Checkpoints and session timestamps accompany each recording. Long pauses in the iPhone recording reflect host stalls. Editors must visually verify usable segments and completed thumbnails before producing the 20-second preview. Raw footage is not an upload-ready App Preview.

French iPhone has four visually verified native screenshots and finalized 72.05-second raw footage in `../footage/localized/fr/iphone/`, committed in `bdb0a7fc6`. All five story thumbnails loaded, reader controls are localized, and Saved Stories margins are clean. Interrupted earlier takes remain outside deliverable paths under `/tmp/newsblur-capture-interrupted-2026-10-16/` and `/tmp/newsblur-fr-resume-hid-interrupted/`.

The remaining 20-language iPad and 19-language iPhone batches are in progress. The canonical English iPad story-list capture will be refreshed before that device’s localized batch. Native RTL navigation coordinates in `capture_locales.rb` are provisional and require a first Arabic/Hebrew visual check before unattended capture. The iPad choreography was verified manually in English, but has not yet run through the locale script. The script waits for real fixture accessibility content and refuses to overwrite an existing recording. Inspect each screenshot for loaded thumbnails; a time delay alone cannot prove all image downloads finished under host contention.

Run from the repository root after backing up both app and shared preferences, using one booted simulator at a time:

```sh
ruby clients/store/artwork/ios/16.0/screenshots/scripts/capture_locales.rb iphone fr
```

Capture and encoding stopped when severe macOS host contention delayed shell, browser, and simulator operations. The coordinator confirmed host recovery and authorized resuming the full native localized capture scope. Final localized rendering, App Preview encoding, uploads, and resubmission remain separate outstanding steps.
