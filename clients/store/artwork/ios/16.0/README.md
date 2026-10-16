# iOS store artwork

The approved, editable artwork is in [`selected/`](selected/README.md). It combines concept 05 wording, concept 08 layout, and the three-view idea from concept 07, using two official iPhone 18 Pro Max frames and one official iPad Pro M5 frame.

The `concepts/` directory retains the earlier concept rounds for reference. Use `selected/index.html` as the source for future header and search-artwork edits. The approved main screenshots use **01 Sage panels**, with native cooking-demo captures in each language.

- [`selected/`](selected/README.md): editable header/search artwork, official device frames, license provenance and 42 localized exports. `selected/submission.json` tracks the separate custom product page submission.
- [`screenshots/`](screenshots/README.md): native captures, localized copy, editable layout, offline renderer and four panels in each of three display sizes per language.
- [`preview/`](preview/README.md): native recordings, localized captions, editable cuts and iPhone/iPad App Preview videos.
- [`resubmission.json`](resubmission.json): main iOS 16.0 release status, verified store placements and outstanding work. Prepared files and custom product page review do not establish submission of the main app version.
- [`proof/`](proof/): persisted-store screenshots, readback evidence and the English placement-pagination diagnosis.

Upload staging uses uniquely named files and SHA-256 provenance in `/tmp/newsblur-ios16-ready-uploads/manifest.json`. Its placement status is separate from rendering and review. After upload, reload App Store Connect, explicitly select the intended language and verify filenames and counts. Keep source assets in the repository so later edits do not depend on temporary upload files.
