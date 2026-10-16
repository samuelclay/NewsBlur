# Preview review evidence

`en/iphone-contact.jpg` samples the 19.5-second iPhone export every half second, reading left to right and top to bottom. `en/ipad-contact.jpg` does the same for the 17-second iPad export. Empty black cells at the end of each sheet are unused grid cells, not frames in either video.

The full-resolution `*-poster.png` files are actual encoded frames at 8 seconds. The `*-ending.png` files show the final Saved Stories screen and disclosure (19 seconds on iPhone, 16.5 seconds on iPad). These images were extracted directly from the final videos without retouching.

The review checked the entire timeline through these sampled frames, with larger frames for readability. Both English exports also played through in QuickTime at normal speed, with UI observations of the beginning, reader progression and Saved Stories ending. App Store processing remains a separate check. Their status is recorded in `../exports/manifest.json`; this folder does not establish submission or approval.

Localized folders use the same half-second contact-sheet sampling. Their `*-title.png`, `*-reader.png` and `*-ending.png` images show full-resolution caption layout from the actual encoded video. Each export's playback status is recorded separately in the manifest; English playback verification does not establish localized playback verification.

French and Arabic iPad contact sheets cover 20 and 22 seconds respectively. French’s ending image is at 19.9 seconds, after the real article-selection transition; Arabic’s is at 21.5 seconds. Native transitions remain in the videos and are not retouched.

German, Hebrew and Spanish iPad exports run 20, 21 and 20 seconds. Their ending images are extracted 0.1 seconds before completion and confirm settled Saved Stories. German and Spanish retain a brief native navigation transition at the start of that scene.
