# Listen launch images and audio

Made October 21, 2026 for `2026-10-30-listen-to-your-stories.md` (written as 2026-10-21, publication dated October 30).

## Screenshots

Every device screen is an unmodified capture from the Listen branch, taken October 21 on the web (dev accounts samuel and hamza, 2880 × 1800), the iPhone and iPad simulators (1170 × 2532 and 1640 × 2360), the Mac app (window captures with their own shadow), and the Galaxy S22 (1080 × 2400). Cards beside the devices are crops of those same captures with nothing added. The originals lived in `~/Desktop/NewsBlur Listen/{Web,iPhone,iPad,Mac,Android}`.

Some Android and web captures show the "minutes left this month" line from a test account.

The story button image (`buttons.html`) was added October 25 from three more unmodified captures in the same folders: `Web/08-story-buttons.png` (2880 × 1800), `iPhone/08-story-buttons.png` (iPhone 17e simulator, 1170 × 2532) and `Android/10-story-buttons.png` (1080 × 2400). It needs no device frames, only `shots/`. The same day the hero (`hero.html`) and the Press Listen image (`start.html`) were redone the same way, as labeled crops of the October 21 captures with no device frames, because four whole screens at once were too small to read.

## Device frames

The composites are rendered in headless Chrome from the HTML in `listen/` and baked into the images, so they show the same in browsers and feed readers.

- iPhone 17 and Galaxy S22: the same Mobile FIRST frames as `assets/iphone-17-frame.png` and `assets/galaxy-s22-frame.png` (see `mobile-release.md`).
- [Apple iPad Air 4](https://www.webmobilefirst.com/en/mockups/apple-ipad-air-4/): its 1640 × 2360 screen matches the iPad captures exactly.
- [MacBook Air](https://www.webmobilefirst.com/en/mockups/macbook-air/): its 16:10 screen matches the web captures.

All four come from Mobile FIRST, whose pages permit personal and commercial use without attribution but not redistribution of the frame alone, so the iPad and MacBook PNGs are not checked in. To re-render, download `mockup-apple-ipad-air-4-transparent.png` and `mockup-macbook-air-transparent.png` from `https://www.webmobilefirst.com/img/mockups/` into a `frames/` folder next to the HTML (naming them `apple-ipad-air-4.png` and `macbook-air.png`, plus the iPhone and Galaxy frames as `apple-iphone-17-2025.png` and `samsung-galaxy-s22-2022.png`), point `shots/` at the screenshot folder, and run `./render.sh <name>`. Each screen sits under its frame at the frame's measured transparent screen bounds (in `base.css`).

`languages.html` reads nothing at render time: its 21 tiles were generated from `localization/languages.json` and the default voice of each language in `apps/listen/voice_catalog.json`. `how.html` is a diagram, not a screenshot.

Hero is a 1600 × 1087 JPEG (it's also the social image). The rest are 1400 px wide WebP at quality 88.

## Audio

`listen-sample-jon.mp3` is the post's first paragraph, generated once through the ElevenLabs text to speech API with exactly what Listen sends for an English story: Jon (`MFZUKuGQUsGJPQjTS4wC`, the English default), `eleven_v4_turbo`, the Natural delivery preset (stability 0.5, similarity 0.75, style 0, speaker boost), `language_code` en, and `mp3_44100_64`. It's 23 seconds and unedited.
