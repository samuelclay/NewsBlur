# Android menu entrances, Samsung validation

Validated on the attached Galaxy S22 (SM-S901U1, Android 16, 1080×2340) without installing an instrumentation APK. Changes are uncommitted.

Menus now fade in and expand from the tapped control over 200 ms, using a decelerating curve and an initial scale of 0.94. The shared popover path covers the main Settings menu, All News and feed action menus, story-list options, feed/story long press, Related Sites, and Mark Read cutoff. Story detail uses the same animation while retaining its existing positioning. Existing theme palettes and dismiss callbacks are preserved.

## Device evidence

- [Settings before](recordings/settings-before.mp4): the frame regression fails as expected, with zero intermediate frames.
- [Settings after](recordings/settings-final.mp4): the final installed build passes, with eight intermediate frames spanning 59 ms in the sampled 15–85% opacity range.
- [All News](recordings/all-news-after.mp4), [individual feed](recordings/feed-titles-after.mp4), and [story-list options](recordings/story-options-after.mp4).
- [Feed long press](recordings/feed-long-press-after.mp4) and [story long press](recordings/story-long-press-after.mp4).
- [Story detail](recordings/detail-final.mp4) on the final installed build.
- [Theme comparison](themes.jpg), left to right: light, sepia, dark, black. Both Settings and story-detail menus were checked in every theme.
- [Landscape detail menu](detail-landscape.png). Rotation dismisses the stale menu, and reopening uses the new bounds. Feed actions were also checked in landscape.
- [Animations disabled](recordings/settings-disabled.mp4): fully visible immediately, with zero intermediate frames.
- [In-place font update](recordings/settings-update.mp4): menu remains opaque; sampled luma varies by only 0.2. Three rapid open/dismiss cycles followed by reopening also passed.

The crash buffer was unchanged. Login was preserved. Theme, rotation, and temporary mark-read preferences were restored. Animator duration was explicitly returned to normal speed (`1`) after the disabled-animation check; window and transition scales remain `1.0`.

## Focused checks

18 JVM tests passed across `Test_PopoverEntranceAnimation`, `Test_ActionMenuHighlight`, `Test_FeedMenuActions`, `Test_StoryTitleSettingsMenu`, and `PopupMenuTextScalerTest`. The eight entrance tests cover first-draw timing, reduced motion, in-place updates, early/during-animation dismissal, failed attachment cleanup, anchor clamping, and a nonzero window origin. `:app:installDebug` and `git diff --check` passed.

`record_menu.rb` captures an entrance at a supplied coordinate without instrumenting the app. `test_menu_entrance.rb` checks the Settings video in Samsung portrait/light theme; optional `--instant` verifies disabled animations, and `--steady` verifies an already-open menu does not fade during an update.

```sh
ruby record_menu.rb R5CT601C8DA /tmp/settings.mp4 954 2193
ruby test_menu_entrance.rb /tmp/settings.mp4
```
