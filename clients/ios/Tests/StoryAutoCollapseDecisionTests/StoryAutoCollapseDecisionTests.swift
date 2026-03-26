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
                usesNativeFullscreenSidebar: false,
                isTemporaryFullScreen: false
            )
        )
    }

    func test_temporary_fullscreen_forces_story_titles_collapsed() {
        XCTAssertTrue(
            StoryAutoCollapseDecision.resolvedShouldCollapse(
                baseShouldCollapse: false,
                fullscreenSidebarPresentation: .fullscreen,
                usesNativeFullscreenSidebar: false,
                isTemporaryFullScreen: true
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

    func test_left_arrow_hides_sidebar_without_cycling_into_feeds() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterKeyboardHide(.fullscreen),
            .fullscreen
        )
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterKeyboardHide(.storyTitles),
            .fullscreen
        )
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterKeyboardHide(.feeds),
            .fullscreen
        )
    }

    func test_right_arrow_only_reveals_story_titles() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterKeyboardReveal(.fullscreen),
            .storyTitles
        )
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterKeyboardReveal(.storyTitles),
            .storyTitles
        )
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterKeyboardReveal(.feeds),
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

    func test_reentrant_story_page_refresh_is_blocked() {
        XCTAssertFalse(
            StoryPageRefreshDecision.shouldBeginRefresh(isRefreshInProgress: true)
        )
    }

    func test_initial_story_page_refresh_is_allowed() {
        XCTAssertTrue(
            StoryPageRefreshDecision.shouldBeginRefresh(isRefreshInProgress: false)
        )
    }

    func test_native_overlay_detects_when_pending_fullscreen_has_not_been_applied_yet() {
        XCTAssertTrue(
            FullscreenSidebarPresentationDecision.needsNativeDisplayModeUpdate(
                for: .fullscreen,
                currentDisplayMode: .twoOverSecondary
            )
        )
    }

    func test_native_overlay_detects_when_current_display_mode_already_matches_pending_state() {
        XCTAssertFalse(
            FullscreenSidebarPresentationDecision.needsNativeDisplayModeUpdate(
                for: .fullscreen,
                currentDisplayMode: .secondaryOnly
            )
        )
        XCTAssertFalse(
            FullscreenSidebarPresentationDecision.needsNativeDisplayModeUpdate(
                for: .storyTitles,
                currentDisplayMode: .oneOverSecondary
            )
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

    func test_non_native_feed_selection_returns_to_story_titles_overlay() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterFeedSelection(
                .storyTitles,
                usesNativeFullscreenSidebar: false
            ),
            .storyTitles
        )
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterFeedSelection(
                .feeds,
                usesNativeFullscreenSidebar: false
            ),
            .storyTitles
        )
    }

    func test_native_feed_selection_returns_to_fullscreen() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterFeedSelection(
                .storyTitles,
                usesNativeFullscreenSidebar: true
            ),
            .fullscreen
        )
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterFeedSelection(
                .feeds,
                usesNativeFullscreenSidebar: true
            ),
            .fullscreen
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

    func test_leading_edge_reveal_opens_story_titles_without_cycling_to_feeds() {
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterLeadingEdgeReveal(.fullscreen),
            .storyTitles
        )
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterLeadingEdgeReveal(.storyTitles),
            .storyTitles
        )
        XCTAssertEqual(
            FullscreenSidebarPresentationDecision.presentationAfterLeadingEdgeReveal(.feeds),
            .storyTitles
        )
    }

    func test_leading_edge_reveal_only_begins_in_fullscreen_overlay_on_ipad() {
        XCTAssertTrue(
            StorySidebarRevealGestureDecision.shouldBeginLeadingEdgeStoryTitlesReveal(
                usesOverlay: true,
                presentation: .fullscreen,
                storyTitlesOnLeft: true,
                isPhoneOrCompact: false
            )
        )
        XCTAssertFalse(
            StorySidebarRevealGestureDecision.shouldBeginLeadingEdgeStoryTitlesReveal(
                usesOverlay: false,
                presentation: .fullscreen,
                storyTitlesOnLeft: true,
                isPhoneOrCompact: false
            )
        )
        XCTAssertFalse(
            StorySidebarRevealGestureDecision.shouldBeginLeadingEdgeStoryTitlesReveal(
                usesOverlay: true,
                presentation: .storyTitles,
                storyTitlesOnLeft: true,
                isPhoneOrCompact: false
            )
        )
        XCTAssertFalse(
            StorySidebarRevealGestureDecision.shouldBeginLeadingEdgeStoryTitlesReveal(
                usesOverlay: true,
                presentation: .fullscreen,
                storyTitlesOnLeft: false,
                isPhoneOrCompact: false
            )
        )
        XCTAssertFalse(
            StorySidebarRevealGestureDecision.shouldBeginLeadingEdgeStoryTitlesReveal(
                usesOverlay: true,
                presentation: .fullscreen,
                storyTitlesOnLeft: true,
                isPhoneOrCompact: true
            )
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

    func test_overlay_always_opens_first_story_on_ipad_even_when_preference_is_list() {
        XCTAssertTrue(
            StoryInitialSelectionDecision.shouldAutomaticallyOpenFirstStory(
                feedOpeningPreference: "list",
                isPhone: false,
                isDashboard: false,
                usesOverlay: true
            )
        )
    }

    func test_non_overlay_respects_story_opening_preference() {
        XCTAssertFalse(
            StoryInitialSelectionDecision.shouldAutomaticallyOpenFirstStory(
                feedOpeningPreference: "list",
                isPhone: false,
                isDashboard: false,
                usesOverlay: false
            )
        )
        XCTAssertTrue(
            StoryInitialSelectionDecision.shouldAutomaticallyOpenFirstStory(
                feedOpeningPreference: "story",
                isPhone: false,
                isDashboard: false,
                usesOverlay: false
            )
        )
    }

    func test_dashboard_never_auto_opens_first_story() {
        XCTAssertFalse(
            StoryInitialSelectionDecision.shouldAutomaticallyOpenFirstStory(
                feedOpeningPreference: "story",
                isPhone: false,
                isDashboard: true,
                usesOverlay: true
            )
        )
    }

    func test_overlay_story_selection_disables_animation_while_sidebar_is_visible() {
        XCTAssertFalse(
            StorySelectionAnimationDecision.shouldAnimateSelection(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: true,
                presentation: .storyTitles
            )
        )
        XCTAssertFalse(
            StorySelectionAnimationDecision.shouldAnimateSelection(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: true,
                presentation: .feeds
            )
        )
        XCTAssertFalse(
            StorySelectionAnimationDecision.shouldAnimateSelection(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: false,
                presentation: .storyTitles
            )
        )
        XCTAssertFalse(
            StorySelectionAnimationDecision.shouldAnimateSelection(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: false,
                presentation: .feeds
            )
        )
    }

    func test_fullscreen_story_selection_keeps_animation() {
        XCTAssertTrue(
            StorySelectionAnimationDecision.shouldAnimateSelection(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: false,
                presentation: .fullscreen
            )
        )
        XCTAssertTrue(
            StorySelectionAnimationDecision.shouldAnimateSelection(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: true,
                presentation: .fullscreen
            )
        )
    }

    func test_phone_story_selection_keeps_animation_even_if_sidebar_state_is_visible() {
        XCTAssertTrue(
            StorySelectionAnimationDecision.shouldAnimateSelection(
                isPhoneOrCompact: true,
                usesNativeFullscreenSidebar: false,
                presentation: .storyTitles
            )
        )
        XCTAssertTrue(
            StorySelectionAnimationDecision.shouldAnimateSelection(
                isPhoneOrCompact: true,
                usesNativeFullscreenSidebar: false,
                presentation: .feeds
            )
        )
    }

    func test_overlay_story_selection_uses_tapped_location_while_sidebar_is_visible() {
        XCTAssertTrue(
            StorySelectionNavigationDecision.shouldUseExplicitLocation(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: true,
                presentation: .storyTitles
            )
        )
        XCTAssertTrue(
            StorySelectionNavigationDecision.shouldUseExplicitLocation(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: true,
                presentation: .feeds
            )
        )
        XCTAssertTrue(
            StorySelectionNavigationDecision.shouldUseExplicitLocation(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: false,
                presentation: .storyTitles
            )
        )
        XCTAssertTrue(
            StorySelectionNavigationDecision.shouldUseExplicitLocation(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: false,
                presentation: .feeds
            )
        )
    }

    func test_fullscreen_story_selection_keeps_active_story_based_navigation() {
        XCTAssertFalse(
            StorySelectionNavigationDecision.shouldUseExplicitLocation(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: false,
                presentation: .fullscreen
            )
        )
        XCTAssertFalse(
            StorySelectionNavigationDecision.shouldUseExplicitLocation(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: true,
                presentation: .fullscreen
            )
        )
    }

    func test_phone_story_selection_keeps_active_story_navigation() {
        XCTAssertFalse(
            StorySelectionNavigationDecision.shouldUseExplicitLocation(
                isPhoneOrCompact: true,
                usesNativeFullscreenSidebar: false,
                presentation: .storyTitles
            )
        )
        XCTAssertFalse(
            StorySelectionNavigationDecision.shouldUseExplicitLocation(
                isPhoneOrCompact: true,
                usesNativeFullscreenSidebar: false,
                presentation: .feeds
            )
        )
    }

    func test_non_animated_story_page_jump_realigns_the_page_controllers_immediately() {
        XCTAssertTrue(
            StoryPageChangeDecision.shouldImmediatelyRealignPages(
                currentPageIndex: 0,
                targetPageIndex: 5,
                animated: false
            )
        )
        XCTAssertTrue(
            StoryPageChangeDecision.shouldImmediatelyRealignPages(
                currentPageIndex: -2,
                targetPageIndex: 0,
                animated: false
            )
        )
    }

    func test_animated_or_no_op_story_page_changes_skip_immediate_realignment() {
        XCTAssertFalse(
            StoryPageChangeDecision.shouldImmediatelyRealignPages(
                currentPageIndex: 0,
                targetPageIndex: 5,
                animated: true
            )
        )
        XCTAssertFalse(
            StoryPageChangeDecision.shouldImmediatelyRealignPages(
                currentPageIndex: 3,
                targetPageIndex: 3,
                animated: false
            )
        )
    }

    func test_overlay_story_selection_skips_sidebar_refresh_while_overlay_is_visible() {
        XCTAssertFalse(
            StorySelectionSidebarRefreshDecision.shouldRefreshStoryTitlesSidebar(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: true,
                presentation: .storyTitles
            )
        )
        XCTAssertFalse(
            StorySelectionSidebarRefreshDecision.shouldRefreshStoryTitlesSidebar(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: true,
                presentation: .feeds
            )
        )
        XCTAssertFalse(
            StorySelectionSidebarRefreshDecision.shouldRefreshStoryTitlesSidebar(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: false,
                presentation: .storyTitles
            )
        )
        XCTAssertFalse(
            StorySelectionSidebarRefreshDecision.shouldRefreshStoryTitlesSidebar(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: false,
                presentation: .feeds
            )
        )
    }

    func test_fullscreen_story_selection_keeps_sidebar_refresh() {
        XCTAssertTrue(
            StorySelectionSidebarRefreshDecision.shouldRefreshStoryTitlesSidebar(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: false,
                presentation: .fullscreen
            )
        )
        XCTAssertTrue(
            StorySelectionSidebarRefreshDecision.shouldRefreshStoryTitlesSidebar(
                isPhoneOrCompact: false,
                usesNativeFullscreenSidebar: true,
                presentation: .fullscreen
            )
        )
    }

    func test_phone_story_selection_keeps_story_titles_sidebar_refresh() {
        XCTAssertTrue(
            StorySelectionSidebarRefreshDecision.shouldRefreshStoryTitlesSidebar(
                isPhoneOrCompact: true,
                usesNativeFullscreenSidebar: false,
                presentation: .storyTitles
            )
        )
        XCTAssertTrue(
            StorySelectionSidebarRefreshDecision.shouldRefreshStoryTitlesSidebar(
                isPhoneOrCompact: true,
                usesNativeFullscreenSidebar: false,
                presentation: .feeds
            )
        )
    }

    func test_story_refresh_keeps_the_selected_story_when_it_is_still_visible() {
        XCTAssertEqual(
            StoryRefreshSelectionDecision.targetLocation(
                activeStoryLocation: 4,
                storyLocationsCount: 10
            ),
            4
        )
    }

    func test_story_refresh_falls_back_to_the_first_story_when_selection_is_gone() {
        XCTAssertEqual(
            StoryRefreshSelectionDecision.targetLocation(
                activeStoryLocation: -1,
                storyLocationsCount: 10
            ),
            0
        )
    }

    func test_story_refresh_returns_no_target_when_there_are_no_stories() {
        XCTAssertEqual(
            StoryRefreshSelectionDecision.targetLocation(
                activeStoryLocation: 2,
                storyLocationsCount: 0
            ),
            -1
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
