import CoreGraphics
import XCTest

@testable import StoryAutoCollapseDecision

final class StoryAutoCollapseDecisionTests: XCTestCase {
    func test_auto_in_portrait_prefers_displace_and_secondary_only() {
        XCTAssertEqual(
            StorySplitBehaviorDecision.preferredBehavior(
                for: "auto",
                width: 1032,
                height: 1376,
                isMac: false
            ),
            .displace
        )
        XCTAssertEqual(
            StorySplitBehaviorDecision.preferredDisplayMode(
                for: "auto",
                width: 1032,
                height: 1376,
                isMac: false
            ),
            .secondaryOnly
        )
    }

    func test_auto_in_landscape_prefers_three_column_tiled_sidebar_layout() {
        XCTAssertTrue(
            StorySplitBehaviorDecision.usesTiledSidebarLayout(
                for: "auto",
                width: 1376,
                height: 1032,
                isMac: false
            )
        )
        XCTAssertEqual(
            StorySplitBehaviorDecision.preferredDisplayMode(
                for: "auto",
                width: 1376,
                height: 1032,
                isMac: false
            ),
            .twoBesideSecondary
        )
    }

    func test_sidebar_toggle_for_portrait_auto_reveals_and_hides_without_tiling() {
        XCTAssertEqual(
            StorySplitBehaviorDecision.sidebarDisplayMode(
                forTiledLayout: false,
                currentDisplayMode: .secondaryOnly
            ),
            .oneOverSecondary
        )
        XCTAssertEqual(
            StorySplitBehaviorDecision.sidebarDisplayMode(
                forTiledLayout: false,
                currentDisplayMode: .oneBesideSecondary
            ),
            .secondaryOnly
        )
        XCTAssertEqual(
            StorySplitBehaviorDecision.sidebarDisplayMode(
                forTiledLayout: false,
                currentDisplayMode: .oneOverSecondary
            ),
            .secondaryOnly
        )
    }

    func test_sidebar_toggle_for_tiled_layout_switches_between_hidden_and_three_columns() {
        XCTAssertEqual(
            StorySplitBehaviorDecision.sidebarDisplayMode(
                forTiledLayout: true,
                currentDisplayMode: .secondaryOnly
            ),
            .twoBesideSecondary
        )
        XCTAssertEqual(
            StorySplitBehaviorDecision.sidebarDisplayMode(
                forTiledLayout: true,
                currentDisplayMode: .twoBesideSecondary
            ),
            .secondaryOnly
        )
    }

    func test_tiled_layout_keeps_temporary_sidebar_reveal_between_folder_switches() {
        XCTAssertFalse(
            StorySplitBehaviorDecision.shouldResetTemporarySidebarReveal(
                for: "auto",
                width: 1376,
                height: 1032,
                isMac: false
            )
        )
        XCTAssertFalse(
            StorySplitBehaviorDecision.shouldResetTemporarySidebarReveal(
                for: "tile",
                width: 1376,
                height: 1032,
                isMac: false
            )
        )
    }

    func test_non_tiled_layout_resets_temporary_sidebar_reveal() {
        XCTAssertTrue(
            StorySplitBehaviorDecision.shouldResetTemporarySidebarReveal(
                for: "auto",
                width: 1032,
                height: 1376,
                isMac: false
            )
        )
        XCTAssertTrue(
            StorySplitBehaviorDecision.shouldResetTemporarySidebarReveal(
                for: "overlay",
                width: 1376,
                height: 1032,
                isMac: false
            )
        )
    }

    func test_overlay_in_portrait_with_story_collapses_story_titles() {
        XCTAssertTrue(
            StoryAutoCollapseDecision.shouldCollapse(
                isPhone: false,
                isCompact: false,
                hasActiveStory: true,
                behavior: .overlay,
                size: CGSize(width: 1032, height: 1376),
                isMac: false
            )
        )
    }

    func test_temporary_fullscreen_story_titles_reveal_skips_overlay_autocollapse() {
        XCTAssertFalse(
            StoryAutoCollapseDecision.resolvedShouldCollapse(
                baseShouldCollapse: true,
                fullscreenSidebarPresentation: .storyTitles,
                usesNativeFullscreenSidebar: false
            )
        )
    }

    func test_fullscreen_sidebar_tap_shows_story_titles_overlay() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterSidebarTap(.fullscreen),
            .storyTitles
        )
    }

    func test_sidebar_tap_from_story_titles_switches_to_feeds() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterSidebarTap(.storyTitles),
            .feeds
        )
    }

    func test_sidebar_tap_from_feeds_cycles_back_to_story_titles() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterSidebarTap(.feeds),
            .storyTitles
        )
    }

    func test_native_display_mode_for_story_titles_is_one_over_secondary() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.nativeDisplayMode(for: .storyTitles),
            .oneOverSecondary
        )
    }

    func test_native_display_mode_for_feeds_is_two_over_secondary() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.nativeDisplayMode(for: .feeds),
            .twoOverSecondary
        )
    }

    func test_secondary_only_display_mode_maps_to_fullscreen() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentation(for: .secondaryOnly),
            .fullscreen
        )
    }

    func test_one_over_secondary_display_mode_maps_to_story_titles() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentation(for: .oneOverSecondary),
            .storyTitles
        )
    }

    func test_two_over_secondary_display_mode_maps_to_feeds() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentation(for: .twoOverSecondary),
            .feeds
        )
    }

    func test_story_selection_dismisses_the_sidebar_popover() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterStorySelection(.storyTitles),
            .fullscreen
        )
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterStorySelection(.feeds),
            .fullscreen
        )
    }

    func test_feed_selection_returns_to_story_titles_overlay() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterFeedSelection(.storyTitles),
            .storyTitles
        )
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterFeedSelection(.feeds),
            .storyTitles
        )
    }

    func test_fullscreen_button_returns_story_titles_or_feeds_to_fullscreen() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterFullscreenButtonTap(.storyTitles),
            .fullscreen
        )
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterFullscreenButtonTap(.feeds),
            .fullscreen
        )
    }

    func test_story_titles_header_shows_fullscreen_button_in_portrait_when_titles_are_visible() {
        XCTAssertTrue(
            StoryTitlesHeaderButtonDecision.showsFullscreenButton(
                for: .storyTitles,
                storyTitlesOnLeft: true,
                usesNativeFullscreenSidebar: false,
                isPhoneOrCompact: false,
                width: 1032,
                height: 1376
            )
        )
        XCTAssertTrue(
            StoryTitlesHeaderButtonDecision.showsFullscreenButton(
                for: .feeds,
                storyTitlesOnLeft: true,
                usesNativeFullscreenSidebar: false,
                isPhoneOrCompact: false,
                width: 1032,
                height: 1376
            )
        )
    }

    func test_story_titles_header_hides_fullscreen_button_when_not_in_portrait_titles_state() {
        XCTAssertFalse(
            StoryTitlesHeaderButtonDecision.showsFullscreenButton(
                for: .fullscreen,
                storyTitlesOnLeft: true,
                usesNativeFullscreenSidebar: false,
                isPhoneOrCompact: false,
                width: 1032,
                height: 1376
            )
        )
        XCTAssertFalse(
            StoryTitlesHeaderButtonDecision.showsFullscreenButton(
                for: .storyTitles,
                storyTitlesOnLeft: true,
                usesNativeFullscreenSidebar: false,
                isPhoneOrCompact: false,
                width: 1376,
                height: 1032
            )
        )
    }

    func test_story_titles_header_shows_fullscreen_button_for_native_overlay_in_landscape() {
        XCTAssertTrue(
            StoryTitlesHeaderButtonDecision.showsFullscreenButton(
                for: .storyTitles,
                storyTitlesOnLeft: true,
                usesNativeFullscreenSidebar: true,
                isPhoneOrCompact: false,
                width: 1376,
                height: 1032
            )
        )
        XCTAssertTrue(
            StoryTitlesHeaderButtonDecision.showsFullscreenButton(
                for: .feeds,
                storyTitlesOnLeft: true,
                usesNativeFullscreenSidebar: true,
                isPhoneOrCompact: false,
                width: 1376,
                height: 1032
            )
        )
    }

    func test_auto_in_landscape_keeps_story_titles_visible() {
        XCTAssertFalse(
            StoryAutoCollapseDecision.shouldCollapse(
                isPhone: false,
                isCompact: false,
                hasActiveStory: true,
                behavior: .auto,
                size: CGSize(width: 1366, height: 1024),
                isMac: false
            )
        )
    }

    func test_tile_never_collapses_story_titles() {
        XCTAssertFalse(
            StoryAutoCollapseDecision.shouldCollapse(
                isPhone: false,
                isCompact: false,
                hasActiveStory: true,
                behavior: .tile,
                size: CGSize(width: 1032, height: 1376),
                isMac: false
            )
        )
    }

    func test_displace_keeps_story_titles_visible() {
        XCTAssertFalse(
            StoryAutoCollapseDecision.shouldCollapse(
                isPhone: false,
                isCompact: false,
                hasActiveStory: true,
                behavior: .displace,
                size: CGSize(width: 1032, height: 1376),
                isMac: false
            )
        )
    }

    func test_without_active_story_keeps_story_titles_visible() {
        XCTAssertFalse(
            StoryAutoCollapseDecision.shouldCollapse(
                isPhone: false,
                isCompact: false,
                hasActiveStory: false,
                behavior: .overlay,
                size: CGSize(width: 1032, height: 1376),
                isMac: false
            )
        )
    }
}
