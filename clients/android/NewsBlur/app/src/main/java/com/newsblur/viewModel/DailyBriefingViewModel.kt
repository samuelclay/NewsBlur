package com.newsblur.viewModel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.database.DatabaseConstants
import com.newsblur.domain.Feed
import com.newsblur.domain.Story
import com.newsblur.network.APIConstants
import com.newsblur.network.BriefingApi
import com.newsblur.network.FeedApi
import com.newsblur.network.domain.DailyBriefingBriefing
import com.newsblur.network.domain.DailyBriefingModelOption
import com.newsblur.network.domain.DailyBriefingStory
import com.newsblur.network.domain.DailyBriefingStoriesResponse
import com.newsblur.util.DailyBriefingPresentationDecision
import com.newsblur.util.DailyBriefingPresentationState
import com.newsblur.util.DailyBriefingSectionLayoutDecision
import com.newsblur.util.DailyBriefingTitleFormatter
import com.newsblur.util.FeedSet
import com.newsblur.util.StateFilter
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import javax.inject.Inject

data class DailyBriefingSectionDefinition(
    val key: String,
    val name: String,
    val subtitle: String,
)

data class DailyBriefingGroupUi(
    val briefingId: String,
    val title: String,
    val dateText: String,
    val storyHashes: List<String>,
    val stories: List<Story>,
    val summaryHash: String?,
    val isPreview: Boolean,
) {
    val curatedCount: Int
        get() = (storyHashes.size - if (summaryHash == null) 0 else 1).coerceAtLeast(0)
}

data class DailyBriefingDraft(
    val enabled: Boolean = true,
    val frequency: String = "daily",
    val preferredTime: String = "morning",
    val preferredDay: String = "sun",
    val storyCount: Int = 10,
    val storySources: String = "all",
    val readFilter: String = "unread",
    val summaryStyle: String = "bullets",
    val includeRead: Boolean = false,
    val builtInSections: Map<String, Boolean> =
        DailyBriefingViewModel.builtInSections.associate { it.key to true },
    val customSectionPrompts: List<String> = emptyList(),
    val customSectionEnabled: List<Boolean> = emptyList(),
    val notificationTypes: Set<String> = emptySet(),
    val briefingFeedId: String? = null,
    val briefingModel: String = "",
    val briefingModels: List<DailyBriefingModelOption> = emptyList(),
    val folders: List<String> = emptyList(),
) {
    val selectedFolder: String?
        get() =
            if (storySources.startsWith("folder:")) {
                storySources.removePrefix("folder:")
            } else {
                null
            }

    fun withSelectedFolder(folderName: String?): DailyBriefingDraft =
        copy(
            storySources =
                if (folderName.isNullOrBlank()) {
                    "all"
                } else {
                    "folder:$folderName"
                },
        )

    fun addKeywordSection(): DailyBriefingDraft =
        if (customSectionPrompts.size >= 5) {
            this
        } else {
            copy(
                customSectionPrompts = customSectionPrompts + "",
                customSectionEnabled = customSectionEnabled + true,
            )
        }

    fun removeKeywordSection(index: Int): DailyBriefingDraft {
        if (index !in customSectionPrompts.indices || index !in customSectionEnabled.indices) {
            return this
        }
        return copy(
            customSectionPrompts =
                customSectionPrompts.filterIndexed { currentIndex, _ ->
                    currentIndex != index
                },
            customSectionEnabled =
                customSectionEnabled.filterIndexed { currentIndex, _ ->
                    currentIndex != index
                },
        )
    }

    fun sectionsPayload(): Map<String, Boolean> =
        buildMap {
            putAll(builtInSections)
            customSectionPrompts.indices.forEach { index ->
                put("custom_${index + 1}", customSectionEnabled.getOrElse(index) { true })
            }
        }

    fun sectionOrderPayload(): List<String> =
        DailyBriefingViewModel.builtInSections.map { it.key } +
            customSectionPrompts.indices.map { index -> "custom_${index + 1}" }

    companion object {
        fun fromResponse(response: com.newsblur.network.domain.DailyBriefingPreferencesResponse): DailyBriefingDraft {
            val builtInSections =
                DailyBriefingViewModel.builtInSections.associate { definition ->
                    definition.key to (response.sections[definition.key] ?: true)
                }
            val customSectionEnabled =
                response.customSectionPrompts.indices.map { index ->
                    response.sections["custom_${index + 1}"] ?: true
                }
            val selectedModel =
                response.briefingModel.takeIf { it.isNotBlank() }
                    ?: response.briefingModels.firstOrNull()?.key.orEmpty()

            return DailyBriefingDraft(
                enabled = response.enabled,
                frequency = response.frequency,
                preferredTime = response.preferredTime,
                preferredDay = response.preferredDay,
                storyCount = response.storyCount,
                storySources = response.storySources,
                readFilter = response.readFilter,
                summaryStyle = response.summaryStyle,
                includeRead = response.includeRead,
                builtInSections = builtInSections,
                customSectionPrompts = response.customSectionPrompts,
                customSectionEnabled = customSectionEnabled,
                notificationTypes = response.notificationTypes.toSet(),
                briefingFeedId = response.briefingFeedId,
                briefingModel = selectedModel,
                briefingModels = response.briefingModels,
                folders = response.folders,
            )
        }
    }
}

data class DailyBriefingUiState(
    val groups: List<DailyBriefingGroupUi> = emptyList(),
    val preferences: DailyBriefingDraft? = null,
    val hasLoadedPreferences: Boolean = false,
    val hasLoadedPreferenceDetails: Boolean = false,
    val isLoadingInitialData: Boolean = false,
    val isLoadingMore: Boolean = false,
    val isSaving: Boolean = false,
    val isGenerating: Boolean = false,
    val progressMessage: String? = null,
    val errorMessage: String? = null,
    val hasNextPage: Boolean = false,
    val currentPage: Int = 1,
    val collapsedGroupIds: Set<String> = emptySet(),
    val showSettingsSheet: Boolean = false,
) {
    val presentationState: DailyBriefingPresentationState
        get() =
            DailyBriefingPresentationDecision.presentationState(
                hasLoadedPreferences = hasLoadedPreferences,
                preferencesEnabled = preferences?.enabled ?: false,
                isLoadingInitialData = isLoadingInitialData,
                hasStories = groups.isNotEmpty(),
            )

    val showSettingsAction: Boolean
        get() = hasLoadedPreferenceDetails && preferences != null && presentationState != DailyBriefingPresentationState.SETTINGS
}

@HiltViewModel
class DailyBriefingViewModel
    @Inject
    constructor(
        private val briefingApi: BriefingApi,
        private val feedApi: FeedApi,
        private val dbHelper: BlurDatabaseHelper,
    ) : ViewModel() {
        private val _uiState = MutableStateFlow(DailyBriefingUiState())
        val uiState: StateFlow<DailyBriefingUiState> = _uiState.asStateFlow()

        private val briefingFeedSet = FeedSet.dailyBriefing()
        private val storedStoriesByHash = linkedMapOf<String, DailyBriefingStory>()
        private var orderedStoryHashes: List<String> = emptyList()
        private var isLoadingPreferences = false

        init {
            refresh()
            loadPreferencesIfNeeded()
        }

        fun refresh() {
            fetchStories(page = 1)
        }

        fun loadPreferencesIfNeeded() {
            if (isLoadingPreferences || _uiState.value.hasLoadedPreferenceDetails) {
                return
            }

            isLoadingPreferences = true
            viewModelScope.launch(Dispatchers.IO) {
                val response = briefingApi.getPreferences()
                isLoadingPreferences = false

                if (response == null || response.isError()) {
                    _uiState.update { current ->
                        current.copy(
                            isLoadingInitialData = false,
                            errorMessage = response?.getErrorMessage("Unable to load Daily Briefing settings.")
                                ?: "Unable to load Daily Briefing settings.",
                        )
                    }
                    return@launch
                }

                val draft = DailyBriefingDraft.fromResponse(response)
                _uiState.update { current ->
                    current.copy(
                        preferences = draft,
                        hasLoadedPreferences = true,
                        hasLoadedPreferenceDetails = true,
                    )
                }
            }
        }

        fun toggleGroup(briefingId: String) {
            _uiState.update { current ->
                current.copy(
                    collapsedGroupIds =
                        current.collapsedGroupIds.toMutableSet().also { collapsed ->
                            if (!collapsed.add(briefingId)) {
                                collapsed.remove(briefingId)
                            }
                        },
                )
            }
        }

        fun loadMoreIfNeeded(briefingId: String) {
            val state = _uiState.value
            if (state.isLoadingMore || !state.hasNextPage) {
                return
            }
            if (!DailyBriefingPresentationDecision.shouldFetchStories(state.currentPage + 1, state.hasLoadedPreferences, state.preferences?.enabled ?: false)) {
                return
            }
            if (state.groups.lastOrNull()?.briefingId != briefingId) {
                return
            }

            fetchStories(page = state.currentPage + 1)
        }

        fun showSettings() {
            _uiState.update { current -> current.copy(showSettingsSheet = true) }
            loadPreferencesIfNeeded()
        }

        fun hideSettings() {
            _uiState.update { current -> current.copy(showSettingsSheet = false) }
        }

        fun savePreferences(
            draft: DailyBriefingDraft,
            generate: Boolean,
        ) {
            if (_uiState.value.isSaving || _uiState.value.isGenerating) {
                return
            }

            _uiState.update { current ->
                current.copy(
                    isSaving = true,
                    errorMessage = null,
                    progressMessage = if (generate) "Saving Daily Briefing settings…" else null,
                )
            }

            viewModelScope.launch(Dispatchers.IO) {
                val saveResponse = briefingApi.savePreferences(makePreferenceParameters(draft, generate))
                if (saveResponse == null || saveResponse.isError()) {
                    _uiState.update { current ->
                        current.copy(
                            isSaving = false,
                            progressMessage = null,
                            errorMessage = saveResponse?.getErrorMessage("Unable to save Daily Briefing settings.")
                                ?: "Unable to save Daily Briefing settings.",
                        )
                    }
                    return@launch
                }

                val savedDraft = draft.copy(enabled = if (generate) true else draft.enabled)
                _uiState.update { current ->
                    current.copy(
                        preferences = savedDraft,
                        hasLoadedPreferences = true,
                        hasLoadedPreferenceDetails = true,
                    )
                }

                if (generate) {
                    generateBriefing(savedDraft)
                } else {
                    val notificationError =
                        saveNotifications(
                            feedId = savedDraft.briefingFeedId,
                            notificationTypes = savedDraft.notificationTypes,
                        )
                    _uiState.update { current ->
                        current.copy(
                            isSaving = false,
                            progressMessage = null,
                            errorMessage = notificationError,
                            showSettingsSheet = false,
                        )
                    }
                }
            }
        }

        suspend fun prepareReadingSession() {
            val hashes = orderedStoryHashes
            if (hashes.isEmpty()) return
            dbHelper.prepareOrderedReadingSession(briefingFeedSet, hashes)
        }

        private fun fetchStories(page: Int) {
            if (page <= 1) {
                _uiState.update { current ->
                    current.copy(
                        isLoadingInitialData = true,
                        errorMessage = null,
                    )
                }
            } else {
                _uiState.update { current ->
                    current.copy(
                        isLoadingMore = true,
                        errorMessage = null,
                    )
                }
            }

            viewModelScope.launch(Dispatchers.IO) {
                val response = briefingApi.getStories(page)
                if (response == null || response.isError()) {
                    _uiState.update { current ->
                        current.copy(
                            isLoadingInitialData = false,
                            isLoadingMore = false,
                            errorMessage = response?.getErrorMessage("Unable to load Daily Briefing.")
                                ?: "Unable to load Daily Briefing.",
                        )
                    }
                    return@launch
                }

                if (page == 1) {
                    storedStoriesByHash.clear()
                    orderedStoryHashes = emptyList()
                }

                val currentPreferences = _uiState.value.preferences
                val effectiveFeedId = response.briefingFeedId ?: currentPreferences?.briefingFeedId
                val responsePreferences =
                    response.preferences?.let { DailyBriefingDraft.fromResponse(it) }
                        ?: currentPreferences?.copy(
                            enabled = response.enabled,
                            briefingFeedId = response.briefingFeedId ?: currentPreferences.briefingFeedId,
                        )
                        ?: DailyBriefingDraft(
                            enabled = response.enabled,
                            briefingFeedId = response.briefingFeedId,
                        )

                val newGroups = buildGroups(response.briefings, response.isPreview, effectiveFeedId)
                val groups =
                    if (page == 1) {
                        newGroups
                    } else {
                        _uiState.value.groups + newGroups.filterNot { newGroup ->
                            _uiState.value.groups.any { it.briefingId == newGroup.briefingId }
                        }
                    }
                persistCurrentStoriesAndSession(groups, effectiveFeedId)
                val collapsedGroups =
                    if (page == 1) {
                        DailyBriefingSectionLayoutDecision.defaultCollapsedGroupIds(groups.map { it.briefingId })
                    } else {
                        _uiState.value.collapsedGroupIds + newGroups.map { it.briefingId }
                    }

                _uiState.update { current ->
                    current.copy(
                        groups = groups,
                        preferences = responsePreferences,
                        hasLoadedPreferences = true,
                        hasLoadedPreferenceDetails = current.hasLoadedPreferenceDetails || response.preferences != null,
                        isLoadingInitialData = false,
                        isLoadingMore = false,
                        hasNextPage = response.hasNextPage,
                        currentPage = response.page,
                        collapsedGroupIds = collapsedGroups,
                    )
                }
            }
        }

        private suspend fun generateBriefing(savedDraft: DailyBriefingDraft) {
            _uiState.update { current ->
                current.copy(
                    isGenerating = true,
                    progressMessage = "Generating your Daily Briefing…",
                )
            }

            val response = briefingApi.generate()
            if (response == null || response.isError()) {
                _uiState.update { current ->
                    current.copy(
                        isSaving = false,
                        isGenerating = false,
                        progressMessage = null,
                        errorMessage = response?.getErrorMessage("Unable to generate Daily Briefing.")
                            ?: "Unable to generate Daily Briefing.",
                    )
                }
                return
            }

            val updatedDraft =
                savedDraft.copy(
                    enabled = true,
                    briefingFeedId = response.briefingFeedId ?: savedDraft.briefingFeedId,
                )
            val notificationError =
                saveNotifications(
                    feedId = updatedDraft.briefingFeedId,
                    notificationTypes = updatedDraft.notificationTypes,
                )

            _uiState.update { current ->
                current.copy(
                    preferences = updatedDraft,
                    isSaving = false,
                    errorMessage = notificationError,
                )
            }

            pollForGeneratedBriefing()
        }

        private suspend fun pollForGeneratedBriefing(remainingAttempts: Int = 20) {
            if (remainingAttempts <= 0) {
                _uiState.update { current ->
                    current.copy(
                        isGenerating = false,
                        progressMessage = null,
                        errorMessage = "Daily Briefing generation timed out. Please try again.",
                    )
                }
                return
            }

            delay(2_000)
            val response = briefingApi.getStories(1)
            if (response == null || response.isError()) {
                pollForGeneratedBriefing(remainingAttempts - 1)
                return
            }

            if (response.briefings.isEmpty()) {
                pollForGeneratedBriefing(remainingAttempts - 1)
                return
            }

            storedStoriesByHash.clear()
            orderedStoryHashes = emptyList()
            val effectiveFeedId = response.briefingFeedId ?: _uiState.value.preferences?.briefingFeedId
            val groups = buildGroups(response.briefings, response.isPreview, effectiveFeedId)
            persistCurrentStoriesAndSession(groups, effectiveFeedId)

            _uiState.update { current ->
                current.copy(
                    groups = groups,
                    preferences =
                        current.preferences?.copy(
                            enabled = true,
                            briefingFeedId = response.briefingFeedId ?: current.preferences.briefingFeedId,
                        ),
                    hasLoadedPreferences = true,
                    isGenerating = false,
                    progressMessage = null,
                    errorMessage = current.errorMessage,
                    hasNextPage = response.hasNextPage,
                    currentPage = response.page,
                    collapsedGroupIds = DailyBriefingSectionLayoutDecision.defaultCollapsedGroupIds(groups.map { it.briefingId }),
                    showSettingsSheet = false,
                )
            }
        }

        private fun buildGroups(
            briefings: List<DailyBriefingBriefing>,
            isPreview: Boolean,
            briefingFeedId: String?,
        ): List<DailyBriefingGroupUi> =
            briefings.map { briefing ->
                val storyHashes = mutableListOf<String>()
                val stories = mutableListOf<Story>()
                val summaryHash =
                    briefing.summaryStory
                        ?.toDisplayStory(briefingFeedId = briefingFeedId, feedLookup = dbHelper::getFeed)
                        ?.let { story ->
                            story.storyHash
                                ?.takeIf { it.isNotBlank() }
                                ?.also { hash ->
                                    storyHashes.add(hash)
                                    stories.add(story)
                                }
                        }

                briefing.curatedStories.forEach { storyPayload ->
                    storyPayload
                        .toDisplayStory(briefingFeedId = briefingFeedId, feedLookup = dbHelper::getFeed)
                        ?.let { story ->
                            story.storyHash
                                ?.takeIf { it.isNotBlank() }
                                ?.also { hash ->
                                    storyHashes.add(hash)
                                    stories.add(story)
                                }
                        }
                }

                briefing.summaryStory?.story?.storyHash
                    ?.takeIf { it.isNotBlank() }
                    ?.let { hash ->
                        storedStoriesByHash[hash] = briefing.summaryStory
                    }
                briefing.curatedStories.forEach { payload ->
                    payload.story.storyHash
                        ?.takeIf { it.isNotBlank() }
                        ?.let { hash ->
                            storedStoriesByHash[hash] = payload
                        }
                }

                DailyBriefingGroupUi(
                    briefingId = briefing.briefingId,
                    title = DailyBriefingTitleFormatter.titleForSlot(briefing.slot),
                    dateText = formatDateTitle(briefing.briefingDate),
                    storyHashes = storyHashes,
                    stories = stories,
                    summaryHash = summaryHash,
                    isPreview = isPreview,
                )
            }

        private fun persistCurrentStoriesAndSession(
            groups: List<DailyBriefingGroupUi>,
            briefingFeedId: String?,
        ) {
            val stories = mutableListOf<Story>()
            val orderedHashes = mutableListOf<String>()

            if (!briefingFeedId.isNullOrBlank()) {
                ensureBriefingFeedExists(briefingFeedId)
            }

            groups.forEach { group ->
                group.storyHashes.forEach { hash ->
                    val payload = storedStoriesByHash[hash] ?: return@forEach
                    payload.normalize(briefingFeedId = briefingFeedId)?.let { story ->
                        stories.add(story)
                        orderedHashes.add(story.storyHash)
                    }
                    if (!payload.isSummary) {
                        ensureFeedExists(payload)
                    }
                }
            }

            if (stories.isEmpty()) {
                orderedStoryHashes = emptyList()
                dbHelper.clearStorySession()
                dbHelper.setSessionFeedSet(briefingFeedSet)
                return
            }

            val apiResponse =
                com.newsblur.network.domain.StoriesResponse().apply {
                    this.stories = stories.toTypedArray()
                }
            dbHelper.insertStories(apiResponse, StateFilter.SOME, false)
            dbHelper.fixMissingStoryFeeds(apiResponse.stories)
            dbHelper.prepareOrderedReadingSession(briefingFeedSet, orderedHashes)
            orderedStoryHashes = orderedHashes
        }

        private fun ensureFeedExists(payload: DailyBriefingStory) {
            val feedId = payload.explicitFeedId ?: payload.story.feedId ?: return
            if (dbHelper.getFeed(feedId) != null) {
                return
            }

            val title = payload.feedTitle ?: return
            dbHelper.updateFeed(
                Feed().apply {
                    this.feedId = feedId
                    this.title = title
                    this.active = true
                    this.faviconColor = payload.faviconColor ?: BRIEFING_FAVICON_COLOR
                    this.faviconFade = BRIEFING_FAVICON_FADE
                    this.faviconBorder = payload.faviconColor ?: BRIEFING_FAVICON_COLOR
                    this.faviconText = "FFFFFF"
                    this.faviconUrl = ""
                },
            )
        }

        private fun ensureBriefingFeedExists(feedId: String) {
            val existing = dbHelper.getFeed(feedId)
            val updatedFeed =
                (existing ?: Feed()).apply {
                    this.feedId = feedId
                    this.title = "Daily Briefing"
                    this.active = true
                    this.faviconColor = BRIEFING_FAVICON_COLOR
                    this.faviconFade = BRIEFING_FAVICON_FADE
                    this.faviconBorder = BRIEFING_FAVICON_COLOR
                    this.faviconText = "FFFFFF"
                    this.faviconUrl = ""
                }
            dbHelper.updateFeed(updatedFeed)
        }

        private suspend fun saveNotifications(
            feedId: String?,
            notificationTypes: Set<String>,
        ): String? {
            if (feedId.isNullOrBlank()) {
                return null
            }

            val response = feedApi.updateFeedNotifications(feedId, notificationTypes.toList().sorted(), null)
            val existing = dbHelper.getFeed(feedId)
            val updatedFeed =
                (existing ?: Feed()).apply {
                    this.feedId = feedId
                    this.title = this.title ?: "Daily Briefing"
                    this.active = true
                    this.notificationTypes = notificationTypes.toList().sorted()
                    this.notificationFilter = null
                    if (this.faviconColor == null) {
                        this.faviconColor = BRIEFING_FAVICON_COLOR
                        this.faviconFade = BRIEFING_FAVICON_FADE
                        this.faviconBorder = BRIEFING_FAVICON_COLOR
                        this.faviconText = "FFFFFF"
                        this.faviconUrl = ""
                    }
                }
            dbHelper.updateFeed(updatedFeed)

            return if (response == null || response.isError()) {
                "Daily Briefing settings were saved, but notifications could not be updated."
            } else {
                null
            }
        }

        private fun makePreferenceParameters(
            draft: DailyBriefingDraft,
            generate: Boolean,
        ): Map<String, String> {
            val enabled = if (generate) true else draft.enabled
            return mapOf(
                "enabled" to enabled.toString(),
                "frequency" to draft.frequency,
                "preferred_time" to draft.preferredTime,
                "preferred_day" to draft.preferredDay,
                "story_count" to draft.storyCount.toString(),
                "story_sources" to draft.storySources,
                "read_filter" to draft.readFilter,
                "summary_style" to draft.summaryStyle,
                "include_read" to draft.includeRead.toString(),
                "sections" to DatabaseConstants.JsonHelper.toJson(draft.sectionsPayload()),
                "custom_section_prompts" to DatabaseConstants.JsonHelper.toJson(draft.customSectionPrompts),
                "section_order" to DatabaseConstants.JsonHelper.toJson(draft.sectionOrderPayload()),
                "briefing_model" to draft.briefingModel,
            )
        }

        companion object {
            private const val BRIEFING_FAVICON_COLOR = "95968E"
            private const val BRIEFING_FAVICON_FADE = "C5C6BE"

            val builtInSections =
                listOf(
                    DailyBriefingSectionDefinition(
                        key = "top_stories",
                        name = "Top stories",
                        subtitle = "The most important stories from your feeds",
                    ),
                    DailyBriefingSectionDefinition(
                        key = "infrequent",
                        name = "From infrequent sites",
                        subtitle = "Stories from feeds that rarely publish",
                    ),
                    DailyBriefingSectionDefinition(
                        key = "long_read",
                        name = "Long reads for later",
                        subtitle = "Longer articles worth setting time aside for",
                    ),
                    DailyBriefingSectionDefinition(
                        key = "classifier_match",
                        name = "Based on your interests",
                        subtitle = "Stories matching your trained topics and authors",
                    ),
                    DailyBriefingSectionDefinition(
                        key = "follow_up",
                        name = "Follow-ups",
                        subtitle = "New posts from feeds you recently read",
                    ),
                    DailyBriefingSectionDefinition(
                        key = "widely_covered",
                        name = "Widely covered",
                        subtitle = "Stories covered by 3+ feeds",
                    ),
                )

            fun formatDateTitle(briefingDate: String?): String {
                if (briefingDate.isNullOrBlank()) return ""
                return runCatching {
                    val formatter =
                        DateTimeFormatter
                            .ofPattern("EEE, MMM d", Locale.getDefault())
                    formatter.format(
                        Instant
                            .parse(briefingDate)
                            .atZone(ZoneId.systemDefault())
                            .toLocalDate(),
                    )
                }.getOrDefault("")
            }
        }
    }

private fun DailyBriefingStory.normalize(briefingFeedId: String?): Story? {
    val normalizedFeedId =
        when {
            isSummary -> briefingFeedId ?: story.feedId ?: explicitFeedId ?: "0"
            !story.feedId.isNullOrBlank() -> story.feedId
            !explicitFeedId.isNullOrBlank() -> explicitFeedId
            !briefingFeedId.isNullOrBlank() -> briefingFeedId
            else -> story.feedId ?: "0"
        }

    return story
        .takeIf { !it.storyHash.isNullOrBlank() }
        ?.also { normalizedStory ->
            normalizedStory.feedId = normalizedFeedId
            normalizedStory.content = normalizedStory.content.orEmpty()
            normalizedStory.title = normalizedStory.title.orEmpty()
            normalizedStory.shortContent = normalizedStory.shortContent.orEmpty()
            normalizedStory.isBriefingSummary = isSummary
        }
}

internal fun DailyBriefingStory.toDisplayStory(
    briefingFeedId: String?,
    feedLookup: (String) -> Feed?,
): Story? =
    normalize(briefingFeedId)?.also { normalizedStory ->
        val feed =
            normalizedStory.feedId
                ?.takeIf { it.isNotBlank() }
                ?.let(feedLookup)
        val resolvedFeedColor = feed?.faviconColor ?: faviconColor ?: normalizedStory.extern_feedColor

        normalizedStory.extern_feedTitle =
            feed?.title ?: feedTitle ?: normalizedStory.extern_feedTitle ?: if (isSummary) "Daily Briefing" else null
        normalizedStory.extern_feedColor = resolvedFeedColor
        normalizedStory.extern_feedFade = feed?.faviconFade ?: normalizedStory.extern_feedFade ?: resolvedFeedColor
        normalizedStory.extern_faviconBorderColor =
            feed?.faviconBorder ?: resolvedFeedColor ?: normalizedStory.extern_faviconBorderColor
        normalizedStory.extern_faviconTextColor =
            feed?.faviconText ?: normalizedStory.extern_faviconTextColor ?: "FFFFFF"

        if (normalizedStory.extern_faviconUrl.isNullOrBlank()) {
            normalizedStory.extern_faviconUrl =
                feed?.faviconUrl?.takeIf { it.isNotBlank() }
                    ?: normalizedStory.feedId
                        ?.takeIf { it.isNotBlank() }
                        ?.let { feedId -> APIConstants.PATH_FEED_FAVICON_URL + feedId }
        }
    }
