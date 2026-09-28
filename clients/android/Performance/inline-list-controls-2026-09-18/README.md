# Inline list appearance controls

Implementation: `efee5e389` on `android-add-discover-sites`. Installed on the attached Samsung Galaxy S22 (Android 16), preserving login. No version bump or Play submission.

The feed-list menu, story-title gear menu, and story-list Options popover share the same inline controls:

- Font size: XS, S, M, L, XL. Changes update the linked feed/story-list preference and keep the menu open. Existing article font size stays independent.
- Theme: Auto plus Light, Sepia, Dark, Black color swatches. The selected choice has a flat pill highlight. Theme changes use the existing activity refresh behavior.
- Appearance controls sit below the story menu actions, without an extra submenu to open. Existing saved font sizes are not changed by opening a menu.

## Validation

- Full `:app:testDebugUnitTest`: 569 passed, zero failures/errors/skips.
- `:app:installDebug`: installed successfully on the Samsung.
- Both feed-list and story-title menus checked in Light, Dark, Black, and Sepia, in portrait and landscape. All five font and theme choices were visible/reachable; no XXL choice was presented.
- Selected XS, S, L, XL, and M in the story menu, verifying the selected button and that the menu stayed open after each selection.
- Selected XL and then M in the feed menu. The menu stayed open and updated its size.
- Checked the story-list Options popover uses the same five-choice inline controls.
- No NewsBlur crash in the device crash buffer.
- Restored original font size, selected theme, Auto light/dark variants, and rotation. Article font size remained unchanged.

Screenshots are named by menu, theme, and orientation. `story-font-*.png` records live font choices, `feed-font-xl.png` records the enlarged feed menu, and `story-options-inline.png` records the Options popover.
