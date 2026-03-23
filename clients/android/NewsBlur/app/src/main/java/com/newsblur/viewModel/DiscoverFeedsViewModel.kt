package com.newsblur.viewModel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.domain.DiscoverFeedPayload
import com.newsblur.domain.Feed
import com.newsblur.network.FeedApi
import com.newsblur.network.domain.DiscoverFeedsResponse
import com.newsblur.util.DiscoverFeedSanitizer
import com.newsblur.util.PrefConstants
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class DiscoverFeedsViewModel
    @Inject
    constructor(
        @ApplicationContext context: Context,
        private val feedApi: FeedApi,
    ) : ViewModel() {
        private val prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE)

        private val _uiState = MutableStateFlow(DiscoverFeedsUiState(viewMode = loadStoredViewMode()))
        val uiState = _uiState.asStateFlow()

        private var similarFeedId: String? = null
        private var similarFeedIds: List<String>? = null
        private var sourceFeed: Feed? = null
        private var currentPage = 0
        private var hasMorePages = true
        private val shownFeedIds = LinkedHashSet<String>()

        fun load(feed: Feed) {
            if (similarFeedId == feed.feedId && similarFeedIds == null && (_uiState.value.feeds.isNotEmpty() || _uiState.value.isLoadingInitial)) {
                return
            }
            sourceFeed = feed
            similarFeedId = feed.feedId
            similarFeedIds = null
            resetAndLoad()
        }

        fun load(feedId: String) {
            if (similarFeedId == feedId && similarFeedIds == null && (_uiState.value.feeds.isNotEmpty() || _uiState.value.isLoadingInitial)) {
                return
            }
            sourceFeed = null
            similarFeedId = feedId
            similarFeedIds = null
            resetAndLoad()
        }

        fun load(feedIds: Collection<String>) {
            val normalizedFeedIds = feedIds.distinct()
            if (normalizedFeedIds.isEmpty()) {
                _uiState.update {
                    it.copy(
                        feeds = emptyList(),
                        isLoadingInitial = false,
                        isLoadingMore = false,
                        errorMessage = "No related sites found",
                    )
                }
                return
            }
            if (similarFeedIds == normalizedFeedIds && similarFeedId == null && (_uiState.value.feeds.isNotEmpty() || _uiState.value.isLoadingInitial)) {
                return
            }
            sourceFeed = null
            similarFeedId = null
            similarFeedIds = normalizedFeedIds
            resetAndLoad()
        }

        fun setViewMode(viewMode: DiscoverFeedViewMode) {
            prefs.edit().putString(PREF_DISCOVER_VIEW_MODE, viewMode.prefValue).apply()
            _uiState.update { it.copy(viewMode = viewMode) }
        }

        fun loadNextPage() {
            if (_uiState.value.isLoadingInitial || _uiState.value.isLoadingMore || !hasMorePages) {
                return
            }
            if (similarFeedId == null && similarFeedIds.isNullOrEmpty()) {
                return
            }
            loadPage(currentPage + 1)
        }

        private fun resetAndLoad() {
            currentPage = 0
            hasMorePages = true
            shownFeedIds.clear()
            _uiState.update {
                it.copy(
                    feeds = emptyList(),
                    isLoadingInitial = false,
                    isLoadingMore = false,
                    errorMessage = null,
                )
            }
            loadPage(1)
        }

        private fun loadPage(pageNumber: Int) {
            viewModelScope.launch(Dispatchers.IO) {
                _uiState.update { state ->
                    if (state.feeds.isEmpty()) {
                        state.copy(isLoadingInitial = true, isLoadingMore = false, errorMessage = null)
                    } else {
                        state.copy(isLoadingInitial = false, isLoadingMore = true, errorMessage = null)
                    }
                }

                val response =
                    runCatching {
                        if (similarFeedId != null) {
                            feedApi.getDiscoverFeeds(similarFeedId!!, pageNumber)
                        } else {
                            feedApi.getDiscoverFeeds(similarFeedIds.orEmpty(), pageNumber)
                        }
                    }.getOrElse { error ->
                        hasMorePages = false
                        _uiState.update { state ->
                            state.copy(
                                isLoadingInitial = false,
                                isLoadingMore = false,
                                errorMessage = error.localizedMessage ?: "No related sites found",
                            )
                        }
                        return@launch
                    }

                val pageFeeds = normalizeDiscoverFeeds(response)
                val rawCount = response?.discoverFeeds?.size ?: 0

                if (pageFeeds.isEmpty()) {
                    if (DiscoverFeedSanitizer.shouldLoadNextPage(pageFeeds, rawCount, pageNumber, MAX_PAGE)) {
                        loadPage(pageNumber + 1)
                        return@launch
                    }
                    hasMorePages = false
                    _uiState.update { state ->
                        state.copy(
                            isLoadingInitial = false,
                            isLoadingMore = false,
                            errorMessage =
                                if (pageNumber == 1 && state.feeds.isEmpty()) {
                                    response?.message ?: "No related sites found"
                                } else {
                                    state.errorMessage
                                },
                        )
                    }
                    return@launch
                }

                currentPage = pageNumber
                hasMorePages = pageNumber < MAX_PAGE && rawCount > 0
                _uiState.update { state ->
                    state.copy(
                        feeds = state.feeds + pageFeeds,
                        isLoadingInitial = false,
                        isLoadingMore = false,
                        errorMessage = null,
                    )
                }
            }
        }

        private fun normalizeDiscoverFeeds(response: DiscoverFeedsResponse?): List<DiscoverFeedPayload> =
            response
                ?.discoverFeeds
                ?.values
                .orEmpty()
                .onEach { it.feed.active = true }
                .sortedByDescending { it.feed.subscribers?.toIntOrNull() ?: 0 }
                .let { DiscoverFeedSanitizer.filterSourceDuplicates(sourceFeed, it) }
                .filter { shownFeedIds.add(it.feed.feedId) }

        private fun loadStoredViewMode(): DiscoverFeedViewMode {
            val storedValue = prefs.getString(PREF_DISCOVER_VIEW_MODE, DiscoverFeedViewMode.GRID.prefValue)
            return DiscoverFeedViewMode.fromPrefValue(storedValue)
        }

        companion object {
            private const val MAX_PAGE = 10
            private const val PREF_DISCOVER_VIEW_MODE = "discover_feeds_view_mode"
        }
    }

data class DiscoverFeedsUiState(
    val feeds: List<DiscoverFeedPayload> = emptyList(),
    val viewMode: DiscoverFeedViewMode = DiscoverFeedViewMode.LIST,
    val isLoadingInitial: Boolean = false,
    val isLoadingMore: Boolean = false,
    val errorMessage: String? = null,
)

enum class DiscoverFeedViewMode(
    val prefValue: String,
) {
    GRID("grid"),
    LIST("list"),
    ;

    companion object {
        fun fromPrefValue(prefValue: String?): DiscoverFeedViewMode =
            entries.firstOrNull { it.prefValue == prefValue } ?: LIST
    }
}
