package com.newsblur.util

enum class DailyBriefingPresentationState {
    LOADING,
    SETTINGS,
    EMPTY,
    STORIES,
}

object DailyBriefingPresentationDecision {
    fun presentationState(
        hasLoadedPreferences: Boolean,
        preferencesEnabled: Boolean,
        isLoadingInitialData: Boolean,
        hasStories: Boolean,
    ): DailyBriefingPresentationState {
        if (!hasLoadedPreferences || (isLoadingInitialData && !hasStories)) {
            return DailyBriefingPresentationState.LOADING
        }

        if (!preferencesEnabled) {
            return DailyBriefingPresentationState.SETTINGS
        }

        return if (hasStories) {
            DailyBriefingPresentationState.STORIES
        } else {
            DailyBriefingPresentationState.EMPTY
        }
    }

    fun shouldFetchStories(
        page: Int,
        hasLoadedPreferences: Boolean,
        preferencesEnabled: Boolean,
    ): Boolean {
        if (page <= 1) {
            return true
        }

        return hasLoadedPreferences && preferencesEnabled
    }
}

object DailyBriefingFolderPlacementDecision {
    @JvmStatic
    fun orderedFolderNames(folderNames: List<String>, isEnabled: Boolean = true): List<String> {
        val foldersWithoutBriefing =
            folderNames.filterNot { it == AppConstants.DAILY_BRIEFING_GROUP_KEY }

        if (!isEnabled) {
            return foldersWithoutBriefing
        }

        val insertionIndex =
            foldersWithoutBriefing.indexOf(AppConstants.INFREQUENT_SITE_STORIES_GROUP_KEY)
                .takeIf { it >= 0 }
                ?: foldersWithoutBriefing.indexOf(AppConstants.ALL_STORIES_GROUP_KEY)
                    .takeIf { it >= 0 }
                ?: 0

        return buildList(foldersWithoutBriefing.size + 1) {
            addAll(foldersWithoutBriefing)
            add(insertionIndex, AppConstants.DAILY_BRIEFING_GROUP_KEY)
        }
    }
}

object DailyBriefingSectionLayoutDecision {
    fun defaultCollapsedGroupIds(groupIds: List<String>): Set<String> = groupIds.drop(1).toSet()
}

object DailyBriefingTitleFormatter {
    fun titleForSlot(slot: String?): String =
        when (slot) {
            "morning" -> "Morning Briefing"
            "afternoon" -> "Afternoon Briefing"
            "evening" -> "Evening Briefing"
            else -> "Daily Briefing"
        }
}
