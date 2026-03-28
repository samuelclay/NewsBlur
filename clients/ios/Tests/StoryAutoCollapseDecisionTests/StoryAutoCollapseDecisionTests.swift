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

    func test_daily_briefing_initial_open_fetches_stories_before_preferences_are_known() {
        XCTAssertEqual(
            DailyBriefingPresentationDecision.presentationState(
                hasLoadedPreferences: false,
                preferencesEnabled: false,
                isLoadingInitialData: true,
                hasStories: false
            ),
            .loading
        )
        XCTAssertFalse(
            DailyBriefingPresentationDecision.shouldFetchStories(
                page: 2,
                hasLoadedPreferences: false,
                preferencesEnabled: false
            )
        )
        XCTAssertTrue(
            DailyBriefingPresentationDecision.shouldFetchStories(
                page: 1,
                hasLoadedPreferences: false,
                preferencesEnabled: false
            )
        )
    }

    func test_daily_briefing_with_disabled_preferences_shows_settings_after_the_story_response() {
        XCTAssertEqual(
            DailyBriefingPresentationDecision.presentationState(
                hasLoadedPreferences: true,
                preferencesEnabled: false,
                isLoadingInitialData: false,
                hasStories: false
            ),
            .settings
        )
        XCTAssertTrue(
            DailyBriefingPresentationDecision.shouldFetchStories(
                page: 1,
                hasLoadedPreferences: true,
                preferencesEnabled: false
            )
        )
        XCTAssertFalse(
            DailyBriefingPresentationDecision.shouldFetchStories(
                page: 2,
                hasLoadedPreferences: true,
                preferencesEnabled: false
            )
        )
    }

    func test_daily_briefing_with_enabled_preferences_loads_stories_then_shows_story_list() {
        XCTAssertEqual(
            DailyBriefingPresentationDecision.presentationState(
                hasLoadedPreferences: true,
                preferencesEnabled: true,
                isLoadingInitialData: true,
                hasStories: false
            ),
            .loading
        )
        XCTAssertEqual(
            DailyBriefingPresentationDecision.presentationState(
                hasLoadedPreferences: true,
                preferencesEnabled: true,
                isLoadingInitialData: false,
                hasStories: true
            ),
            .stories
        )
        XCTAssertTrue(
            DailyBriefingPresentationDecision.shouldFetchStories(
                page: 1,
                hasLoadedPreferences: true,
                preferencesEnabled: true
            )
        )
        XCTAssertTrue(
            DailyBriefingPresentationDecision.shouldFetchStories(
                page: 2,
                hasLoadedPreferences: true,
                preferencesEnabled: true
            )
        )
    }

    func test_daily_briefing_link_extracts_story_hash_for_internal_navigation() {
        XCTAssertEqual(
            DailyBriefingLinkDecision.storyHash(
                for: NSURL(string: "https://www.newsblur.com/briefing?story=feed%3A1"),
                isDailyBriefing: true
            ),
            "feed:1"
        )
    }

    func test_daily_briefing_link_ignores_non_briefing_urls() {
        XCTAssertNil(
            DailyBriefingLinkDecision.storyHash(
                for: NSURL(string: "https://example.com/article?story=feed%3A1"),
                isDailyBriefing: true
            )
        )
        XCTAssertNil(
            DailyBriefingLinkDecision.storyHash(
                for: NSURL(string: "https://www.newsblur.com/briefing?story=feed%3A1"),
                isDailyBriefing: false
            )
        )
    }

    func test_daily_briefing_pagination_waits_for_user_scroll() {
        XCTAssertFalse(
            DailyBriefingPaginationDecision.shouldPrefetchNextPage(
                remainingOffset: 120,
                isDragging: false,
                isDecelerating: false
            )
        )
        XCTAssertTrue(
            DailyBriefingPaginationDecision.shouldPrefetchNextPage(
                remainingOffset: 120,
                isDragging: true,
                isDecelerating: false
            )
        )
        XCTAssertTrue(
            DailyBriefingPaginationDecision.shouldPrefetchNextPage(
                remainingOffset: 120,
                isDragging: false,
                isDecelerating: true
            )
        )
    }

    func test_daily_briefing_pagination_ignores_far_offsets() {
        XCTAssertFalse(
            DailyBriefingPaginationDecision.shouldPrefetchNextPage(
                remainingOffset: 800,
                isDragging: true,
                isDecelerating: true
            )
        )
    }

    func test_daily_briefing_folder_appears_before_infrequent_site_stories() {
        XCTAssertEqual(
            DailyBriefingFolderPlacementDecision.orderedFolders(
                folderNames: ["dashboard", "infrequent", "everything", "tech"],
                isEnabled: true
            ),
            ["dashboard", "daily_briefing", "infrequent", "everything", "tech"]
        )
    }

    func test_daily_briefing_folder_keeps_its_top_section_slot_when_disabled() {
        XCTAssertEqual(
            DailyBriefingFolderPlacementDecision.orderedFolders(
                folderNames: ["dashboard", "daily_briefing", "infrequent", "everything"],
                isEnabled: false
            ),
            ["dashboard", "daily_briefing", "infrequent", "everything"]
        )
    }

    func test_daily_briefing_defaults_only_the_latest_group_to_expanded() {
        XCTAssertEqual(
            DailyBriefingSectionLayoutDecision.defaultCollapsedGroupIDs(for: ["latest", "older", "oldest"]),
            Set(["older", "oldest"])
        )
        XCTAssertEqual(
            DailyBriefingSectionLayoutDecision.defaultCollapsedGroupIDs(for: ["latest"]),
            []
        )
    }

    func test_daily_briefing_section_layout_maps_rows_and_loading_section() {
        let sections = DailyBriefingSectionLayoutDecision.sections(
            groups: [
                DailyBriefingListGroup(
                    id: "latest",
                    title: "Morning Briefing",
                    dateText: "Today, Mar 27",
                    storyHashes: ["summary", "story-1", "story-2"]
                ),
                DailyBriefingListGroup(
                    id: "older",
                    title: "Evening Briefing",
                    dateText: "Yesterday, Mar 26",
                    storyHashes: ["story-3"]
                ),
            ],
            storyLocationsByHash: [
                "summary": 0,
                "story-1": 1,
                "story-2": 2,
                "story-3": 3,
            ],
            collapsedGroupIDs: ["older"],
            includesLoadingSection: true
        )

        XCTAssertEqual(
            sections,
            [
                DailyBriefingListSection(
                    id: "latest",
                    title: "Morning Briefing",
                    dateText: "Today, Mar 27",
                    rowLocations: [0, 1, 2],
                    isCollapsed: false,
                    isLoadingSection: false
                ),
                DailyBriefingListSection(
                    id: "older",
                    title: "Evening Briefing",
                    dateText: "Yesterday, Mar 26",
                    rowLocations: [3],
                    isCollapsed: true,
                    isLoadingSection: false
                ),
                DailyBriefingListSection(
                    id: "__loading__",
                    title: "",
                    dateText: "",
                    rowLocations: [],
                    isCollapsed: false,
                    isLoadingSection: true
                ),
            ]
        )
    }

    func test_daily_briefing_story_lookup_uses_raw_story_indexes() {
        XCTAssertEqual(
            StoryRowLookupDecision.storyIndex(
                for: 2,
                isDailyBriefing: true,
                allStoriesCount: 4,
                visibleStoryLocations: []
            )?.intValue,
            2
        )
    }

    func test_non_briefing_story_lookup_uses_visible_story_locations() {
        XCTAssertEqual(
            StoryRowLookupDecision.storyIndex(
                for: 1,
                isDailyBriefing: false,
                allStoriesCount: 10,
                visibleStoryLocations: [5, 7, 9]
            )?.intValue,
            7
        )
    }

    func test_daily_briefing_legacy_rows_do_not_fall_back_to_loading_without_row_descriptors() {
        XCTAssertFalse(
            FeedRowLoadingDecision.shouldShowLoadingCell(
                isLegacyTable: true,
                isDailyBriefing: true,
                hasRowDescriptor: false,
                storyLocation: 0,
                storyCount: 4
            )
        )
    }

    func test_non_briefing_legacy_rows_still_use_loading_when_the_descriptor_is_missing() {
        XCTAssertTrue(
            FeedRowLoadingDecision.shouldShowLoadingCell(
                isLegacyTable: true,
                isDailyBriefing: false,
                hasRowDescriptor: false,
                storyLocation: 0,
                storyCount: 4
            )
        )
    }

    func test_phone_story_titles_return_frame_snaps_back_to_full_width() {
        XCTAssertEqual(
            FeedDetailReturnFrameDecision.correctedFrame(
                CGRect(x: 0, y: 0, width: 247, height: 720),
                containerBounds: CGRect(x: 0, y: 0, width: 393, height: 852),
                navigationBarMinY: 0,
                isPhoneOrCompact: true
            ),
            CGRect(x: 0, y: 0, width: 393, height: 720)
        )
    }

    func test_phone_story_titles_return_frame_keeps_regular_width_on_ipad() {
        XCTAssertEqual(
            FeedDetailReturnFrameDecision.correctedFrame(
                CGRect(x: 0, y: 0, width: 247, height: 720),
                containerBounds: CGRect(x: 0, y: 0, width: 393, height: 852),
                navigationBarMinY: 0,
                isPhoneOrCompact: false
            ),
            CGRect(x: 0, y: 0, width: 247, height: 720)
        )
    }

    func test_phone_story_titles_return_frame_preserves_nav_bar_y_workaround() {
        XCTAssertEqual(
            FeedDetailReturnFrameDecision.correctedFrame(
                CGRect(x: 0, y: 0, width: 393, height: 720),
                containerBounds: CGRect(x: 0, y: 0, width: 393, height: 852),
                navigationBarMinY: -59,
                isPhoneOrCompact: true
            ),
            CGRect(x: 0, y: 59, width: 393, height: 720)
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

    func test_feed_list_leading_edge_reveal_does_not_require_cached_presentation_to_be_primed() {
        XCTAssertTrue(
            FeedSidebarRevealGestureDecision.shouldBeginLeadingEdgeFeedsReveal(
                presentation: .storyTitles,
                isPhoneOrCompact: false
            )
        )
        XCTAssertTrue(
            FeedSidebarRevealGestureDecision.shouldBeginLeadingEdgeFeedsReveal(
                presentation: .feeds,
                isPhoneOrCompact: false
            )
        )
        XCTAssertTrue(
            FeedSidebarRevealGestureDecision.shouldBeginLeadingEdgeFeedsReveal(
                presentation: .fullscreen,
                isPhoneOrCompact: false
            )
        )
        XCTAssertFalse(
            FeedSidebarRevealGestureDecision.shouldBeginLeadingEdgeFeedsReveal(
                presentation: .storyTitles,
                isPhoneOrCompact: true
            )
        )
    }

    func test_story_detail_toolbar_shows_temporary_fullscreen_button_for_visible_story_in_column_mode() {
        XCTAssertTrue(
            StoryDetailFullscreenButtonDecision.showsTemporaryFullscreenButton(
                storyDetailVisible: true,
                isPhoneOrCompact: false,
                isMac: false,
                isUserOverlayMode: false,
                isTemporaryFullScreen: false
            )
        )
    }

    func test_story_detail_toolbar_hides_temporary_fullscreen_button_without_a_visible_story() {
        XCTAssertFalse(
            StoryDetailFullscreenButtonDecision.showsTemporaryFullscreenButton(
                storyDetailVisible: false,
                isPhoneOrCompact: false,
                isMac: false,
                isUserOverlayMode: false,
                isTemporaryFullScreen: false
            )
        )
        XCTAssertFalse(
            StoryDetailFullscreenButtonDecision.showsTemporaryFullscreenButton(
                storyDetailVisible: true,
                isPhoneOrCompact: true,
                isMac: false,
                isUserOverlayMode: false,
                isTemporaryFullScreen: false
            )
        )
        XCTAssertFalse(
            StoryDetailFullscreenButtonDecision.showsTemporaryFullscreenButton(
                storyDetailVisible: true,
                isPhoneOrCompact: false,
                isMac: true,
                isUserOverlayMode: false,
                isTemporaryFullScreen: false
            )
        )
    }

    func test_story_detail_toolbar_keeps_temporary_fullscreen_button_visible_while_fullscreen_in_overlay_mode() {
        XCTAssertTrue(
            StoryDetailFullscreenButtonDecision.showsTemporaryFullscreenButton(
                storyDetailVisible: true,
                isPhoneOrCompact: false,
                isMac: false,
                isUserOverlayMode: true,
                isTemporaryFullScreen: true
            )
        )
        XCTAssertFalse(
            StoryDetailFullscreenButtonDecision.showsTemporaryFullscreenButton(
                storyDetailVisible: true,
                isPhoneOrCompact: false,
                isMac: false,
                isUserOverlayMode: true,
                isTemporaryFullScreen: false
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

    func test_feed_selection_on_regular_width_loads_story_titles_immediately() {
        XCTAssertEqual(
            FeedSelectionPresentationDecision.presentation(
                isPhone: false,
                userInterfaceIdiomPhone: false
            ),
            .loadFeedDetail
        )
    }

    func test_feed_selection_on_iphone_shows_feed_list_then_story_titles() {
        XCTAssertEqual(
            FeedSelectionPresentationDecision.presentation(
                isPhone: true,
                userInterfaceIdiomPhone: true
            ),
            .showFeedsListThenLoadFeedDetail
        )
    }

    func test_feed_selection_on_compact_ipad_waits_for_existing_navigation_flow() {
        XCTAssertEqual(
            FeedSelectionPresentationDecision.presentation(
                isPhone: true,
                userInterfaceIdiomPhone: false
            ),
            .wait
        )
    }
}
