# Native capture checkpoint, 2026-10-16

All simulators are shut down. The iPhone's three preference files were restored and SHA-256 verified against `/tmp/newsblur-iphone-capture-final-backup`; the iPad's five files were restored from `/tmp/newsblur-ipad-capture-final-backup`. No production account was used.

English has four verified iPhone and four verified iPad screenshots in `../captures/`. The iPhone story list retains the earlier experimental-layout capture because it has all five photo thumbnails. The refreshed iPhone feed list, article reader, and Saved Stories use standard layout; standard avoids clipped Saved Stories margins. iPad uses standard throughout. These are unretouched native captures of actual supported layouts.

Raw English footage is finalized in `../footage/iphone/scroll.mp4` (116.36 seconds) and `../footage/ipad/scroll.mp4` (27.75 seconds). Checkpoints and session timestamps accompany each recording. Long pauses in the iPhone recording reflect host stalls. Editors must visually verify usable segments and completed thumbnails before producing the 20-second preview. Raw footage is not an upload-ready App Preview.

French iPhone feed list and article reader are verified in `../captures/localized/fr/`. French story list requires recapture after all thumbnails appear; Saved Stories and the full recording remain incomplete. Interrupted French footage and rejected stills are preserved outside the deliverable paths in `/tmp/newsblur-capture-interrupted-2026-10-16/`. The earlier experimental French recording remains in `/tmp/newsblur-fr-iphone-experimental-footage/` for reference only.

The remaining 20-language iPad and 19-language iPhone batches have not run. French iPhone still needs its missing states and recording. Native RTL navigation coordinates in `capture_locales.rb` are provisional and require a first Arabic/Hebrew visual check before unattended capture. The iPad choreography was verified manually in English, but has not yet run through the locale script. The script waits for real fixture accessibility content and refuses to overwrite an existing recording. Inspect each screenshot for loaded thumbnails; a time delay alone cannot prove all image downloads finished under host contention.

Run from the repository root after backing up both app and shared preferences, using one booted simulator at a time:

```sh
ruby clients/store/artwork/ios/16.0/screenshots/scripts/capture_locales.rb iphone fr
```

Capture and encoding stopped when severe macOS host contention delayed shell, browser, and simulator operations. Do not resume or boot another simulator until the coordinator confirms host recovery. Final localized rendering, App Preview encoding, uploads, and resubmission remain separate outstanding steps.
