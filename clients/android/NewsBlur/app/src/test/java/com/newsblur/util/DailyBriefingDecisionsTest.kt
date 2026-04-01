package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DailyBriefingDecisionsTest {
    @Test
    fun `daily briefing folder appears before infrequent site stories`() {
        assertEquals(
            listOf(
                AppConstants.DAILY_BRIEFING_GROUP_KEY,
                AppConstants.INFREQUENT_SITE_STORIES_GROUP_KEY,
                AppConstants.ALL_STORIES_GROUP_KEY,
                "tech",
            ),
            DailyBriefingFolderPlacementDecision.orderedFolderNames(
                listOf(
                    AppConstants.INFREQUENT_SITE_STORIES_GROUP_KEY,
                    AppConstants.ALL_STORIES_GROUP_KEY,
                    "tech",
                ),
            ),
        )
    }

    @Test
    fun `daily briefing folder appears before all stories when infrequent row is absent`() {
        assertEquals(
            listOf(
                AppConstants.DAILY_BRIEFING_GROUP_KEY,
                AppConstants.ALL_STORIES_GROUP_KEY,
                "tech",
            ),
            DailyBriefingFolderPlacementDecision.orderedFolderNames(
                listOf(
                    AppConstants.ALL_STORIES_GROUP_KEY,
                    "tech",
                ),
            ),
        )
    }

    @Test
    fun `daily briefing folder is not duplicated`() {
        assertEquals(
            listOf(
                AppConstants.DAILY_BRIEFING_GROUP_KEY,
                AppConstants.INFREQUENT_SITE_STORIES_GROUP_KEY,
                AppConstants.ALL_STORIES_GROUP_KEY,
            ),
            DailyBriefingFolderPlacementDecision.orderedFolderNames(
                listOf(
                    AppConstants.DAILY_BRIEFING_GROUP_KEY,
                    AppConstants.INFREQUENT_SITE_STORIES_GROUP_KEY,
                    AppConstants.ALL_STORIES_GROUP_KEY,
                ),
            ),
        )
    }

    @Test
    fun `daily briefing folder is hidden when disabled`() {
        assertEquals(
            listOf(
                AppConstants.INFREQUENT_SITE_STORIES_GROUP_KEY,
                AppConstants.ALL_STORIES_GROUP_KEY,
                "tech",
            ),
            DailyBriefingFolderPlacementDecision.orderedFolderNames(
                listOf(
                    AppConstants.INFREQUENT_SITE_STORIES_GROUP_KEY,
                    AppConstants.ALL_STORIES_GROUP_KEY,
                    "tech",
                ),
                isEnabled = false,
            ),
        )
    }

    @Test
    fun `daily briefing folder is removed when disabled even if already present`() {
        assertEquals(
            listOf(
                AppConstants.INFREQUENT_SITE_STORIES_GROUP_KEY,
                AppConstants.ALL_STORIES_GROUP_KEY,
            ),
            DailyBriefingFolderPlacementDecision.orderedFolderNames(
                listOf(
                    AppConstants.DAILY_BRIEFING_GROUP_KEY,
                    AppConstants.INFREQUENT_SITE_STORIES_GROUP_KEY,
                    AppConstants.ALL_STORIES_GROUP_KEY,
                ),
                isEnabled = false,
            ),
        )
    }

    @Test
    fun `presentation state remains loading until preferences or stories are ready`() {
        assertEquals(
            DailyBriefingPresentationState.LOADING,
            DailyBriefingPresentationDecision.presentationState(
                hasLoadedPreferences = false,
                preferencesEnabled = false,
                isLoadingInitialData = true,
                hasStories = false,
            ),
        )
        assertEquals(
            DailyBriefingPresentationState.LOADING,
            DailyBriefingPresentationDecision.presentationState(
                hasLoadedPreferences = true,
                preferencesEnabled = true,
                isLoadingInitialData = true,
                hasStories = false,
            ),
        )
    }

    @Test
    fun `presentation state shows settings when preferences are disabled`() {
        assertEquals(
            DailyBriefingPresentationState.SETTINGS,
            DailyBriefingPresentationDecision.presentationState(
                hasLoadedPreferences = true,
                preferencesEnabled = false,
                isLoadingInitialData = false,
                hasStories = false,
            ),
        )
    }

    @Test
    fun `presentation state shows empty or stories after enabled preferences load`() {
        assertEquals(
            DailyBriefingPresentationState.EMPTY,
            DailyBriefingPresentationDecision.presentationState(
                hasLoadedPreferences = true,
                preferencesEnabled = true,
                isLoadingInitialData = false,
                hasStories = false,
            ),
        )
        assertEquals(
            DailyBriefingPresentationState.STORIES,
            DailyBriefingPresentationDecision.presentationState(
                hasLoadedPreferences = true,
                preferencesEnabled = true,
                isLoadingInitialData = false,
                hasStories = true,
            ),
        )
    }

    @Test
    fun `first daily briefing page always fetches stories`() {
        assertTrue(
            DailyBriefingPresentationDecision.shouldFetchStories(
                page = 1,
                hasLoadedPreferences = false,
                preferencesEnabled = false,
            ),
        )
    }

    @Test
    fun `later pages require enabled preferences`() {
        assertFalse(
            DailyBriefingPresentationDecision.shouldFetchStories(
                page = 2,
                hasLoadedPreferences = false,
                preferencesEnabled = true,
            ),
        )
        assertFalse(
            DailyBriefingPresentationDecision.shouldFetchStories(
                page = 2,
                hasLoadedPreferences = true,
                preferencesEnabled = false,
            ),
        )
        assertTrue(
            DailyBriefingPresentationDecision.shouldFetchStories(
                page = 2,
                hasLoadedPreferences = true,
                preferencesEnabled = true,
            ),
        )
    }

    @Test
    fun `only the latest briefing group defaults to expanded`() {
        assertEquals(
            setOf("older", "oldest"),
            DailyBriefingSectionLayoutDecision.defaultCollapsedGroupIds(
                listOf("latest", "older", "oldest"),
            ),
        )
        assertEquals(
            emptySet<String>(),
            DailyBriefingSectionLayoutDecision.defaultCollapsedGroupIds(listOf("latest")),
        )
    }

    @Test
    fun `briefing slot titles match iOS naming`() {
        assertEquals("Morning Briefing", DailyBriefingTitleFormatter.titleForSlot("morning"))
        assertEquals("Afternoon Briefing", DailyBriefingTitleFormatter.titleForSlot("afternoon"))
        assertEquals("Evening Briefing", DailyBriefingTitleFormatter.titleForSlot("evening"))
        assertEquals("Daily Briefing", DailyBriefingTitleFormatter.titleForSlot("unexpected"))
    }
}
