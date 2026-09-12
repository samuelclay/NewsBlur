package com.newsblur.viewModel

import android.os.CancellationSignal
import android.util.Log
import androidx.annotation.MainThread
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.BuildConfig
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Feed
import com.newsblur.domain.FeedQueryResult
import com.newsblur.domain.Folder
import com.newsblur.domain.FolderQueryResult
import com.newsblur.domain.SavedSearch
import com.newsblur.domain.SavedStoryCountsQueryResult
import com.newsblur.domain.SocialFeed
import com.newsblur.domain.StarredCount
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import java.util.Collections
import javax.inject.Inject

@HiltViewModel
class AllFoldersViewModel
    internal constructor(
        private val dbHelper: BlurDatabaseHelper,
        private val queryDispatcher: CoroutineDispatcher,
    ) : ViewModel() {
        @Inject
        constructor(dbHelper: BlurDatabaseHelper) : this(dbHelper, Dispatchers.IO)

        private val _socialFeeds = MutableLiveData<List<SocialFeed>>()
        val socialFeeds: LiveData<List<SocialFeed>> = _socialFeeds

        private val _folders = MutableLiveData<FolderQueryResult>()
        val folders: LiveData<FolderQueryResult> = _folders

        private val _feeds = MutableLiveData<FeedQueryResult>()
        var feeds: LiveData<FeedQueryResult> = _feeds

        private val _savedStoryCounts = MutableLiveData<SavedStoryCountsQueryResult>()
        val savedStoryCounts: LiveData<SavedStoryCountsQueryResult> = _savedStoryCounts

        private val _savedSearch = MutableLiveData<List<SavedSearch>>()
        val savedSearch: LiveData<List<SavedSearch>> = _savedSearch

        private val loader =
            LatestStoryLoadRunner(
                scope = viewModelScope,
                queryDispatcher = queryDispatcher,
                load = ::readSnapshot,
                cancel = { request: LoadRequest -> request.cancellationSignal.cancel() },
                publish = ::publishSnapshot,
                sameQuery = { _, _ -> true },
                onError = { error -> Log.e(javaClass.name, "Error loading cached feed snapshot", error) },
            )

        @MainThread
        fun getData() {
            // FolderListFragment.java can receive several metadata/read updates during one cached load.
            // LatestStoryLoadRunner.kt finishes that snapshot and keeps just the newest followup request.
            loader.submit(LoadRequest(CancellationSignal(), System.nanoTime()))
        }

        private fun readSnapshot(request: LoadRequest): Snapshot {
            val signal = request.cancellationSignal
            val folders = readFolders(signal)
            val feeds = readFeeds(signal)
            val socialFeeds = readSocialFeeds(signal)
            val savedStoryCounts = readSavedStoryCounts(signal)
            val savedSearches = readSavedSearches(signal)
            signal.throwIfCanceled()
            return Snapshot(folders, feeds, socialFeeds, savedStoryCounts, savedSearches, request.requestedAtNanos)
        }

        private fun publishSnapshot(snapshot: Snapshot) {
            // FolderListFragment.java receives all cached sections in one Main turn. Publishing social
            // feeds earlier showed a partial feed list and incorrect account totals during cold startup.
            _folders.value = snapshot.folders
            _feeds.value = snapshot.feeds
            _socialFeeds.value = snapshot.socialFeeds
            _savedStoryCounts.value = snapshot.savedStoryCounts
            _savedSearch.value = snapshot.savedSearches
            if (BuildConfig.DEBUG) {
                val elapsedMillis = (System.nanoTime() - snapshot.requestedAtNanos) / 1_000_000
                Log.d("NB.FeedLoad", "publish feeds=${snapshot.feeds.feeds.size} folders=${snapshot.folders.folders.size} elapsedMs=$elapsedMillis")
            }
        }

        private fun readFolders(signal: CancellationSignal): FolderQueryResult =
            dbHelper.getFoldersCursor(signal).use { cursor ->
                val folders = LinkedHashMap<String, Folder>(cursor.count)
                val flatFolders = LinkedHashMap<String, Folder>(cursor.count)
                while (cursor.moveToNext()) {
                    signal.throwIfCanceled()
                    val folder = Folder.fromCursor(cursor)
                    folders[folder.name] = folder
                    flatFolders[folder.flatName()] = folder
                }
                FolderQueryResult(folders, flatFolders)
            }

        private fun readFeeds(signal: CancellationSignal): FeedQueryResult =
            dbHelper.getFeedsCursor(signal).use { cursor ->
                val feeds = LinkedHashMap<String, Feed>(cursor.count)
                val feedNeutCounts = mutableMapOf<String, Int>()
                val feedPosCounts = mutableMapOf<String, Int>()
                var totalNeutCount = 0
                var totalPosCount = 0
                var totalActiveFeedCount = 0
                while (cursor.moveToNext()) {
                    signal.throwIfCanceled()
                    val feed = Feed.fromCursor(cursor)
                    feeds[feed.feedId] = feed
                    if (feed.active && feed.positiveCount > 0) {
                        val positive = checkNegativeFeedUnreads(feed.positiveCount)
                        feedPosCounts[feed.feedId] = positive
                        totalPosCount += positive
                    }
                    if (feed.active && feed.neutralCount > 0) {
                        val neutral = checkNegativeFeedUnreads(feed.neutralCount)
                        feedNeutCounts[feed.feedId] = neutral
                        totalNeutCount += neutral
                    }
                    if (feed.active) totalActiveFeedCount++
                }
                FeedQueryResult(feeds, feedNeutCounts, feedPosCounts, totalNeutCount, totalPosCount, totalActiveFeedCount)
            }

        private fun readSocialFeeds(signal: CancellationSignal): List<SocialFeed> =
            dbHelper.getSocialFeedsCursor(signal).use { cursor ->
                val socialFeeds = ArrayList<SocialFeed>(cursor.count)
                while (cursor.moveToNext()) {
                    signal.throwIfCanceled()
                    socialFeeds.add(SocialFeed.fromCursor(cursor))
                }
                socialFeeds
            }

        private fun readSavedStoryCounts(signal: CancellationSignal): SavedStoryCountsQueryResult =
            dbHelper.getSavedStoryCountsCursor(signal).use { cursor ->
                val starredCountsByTag = mutableListOf<StarredCount>()
                val feedSavedCounts = mutableMapOf<String, Int>()
                var savedStoriesTotalCount: Int? = null
                while (cursor.moveToNext()) {
                    signal.throwIfCanceled()
                    val count = StarredCount.fromCursor(cursor)
                    if (count.isTotalCount) {
                        savedStoriesTotalCount = count.count
                    } else if (count.tag != null) {
                        starredCountsByTag.add(count)
                    } else if (count.feedId != null) {
                        feedSavedCounts[count.feedId] = count.count
                    }
                }
                Collections.sort(starredCountsByTag, StarredCount.StarredCountComparatorByTag)
                SavedStoryCountsQueryResult(starredCountsByTag, feedSavedCounts, savedStoriesTotalCount)
            }

        private fun readSavedSearches(signal: CancellationSignal): List<SavedSearch> =
            dbHelper.getSavedSearchCursor(signal).use { cursor ->
                val savedSearches = mutableListOf<SavedSearch>()
                while (cursor.moveToNext()) {
                    signal.throwIfCanceled()
                    savedSearches.add(SavedSearch.fromCursor(cursor))
                }
                Collections.sort(savedSearches, SavedSearch.SavedSearchComparatorByTitle)
                savedSearches
            }

        /** AllFoldersViewModel.kt clamps negative unread counts reported by an inconsistent cache/API. */
        private fun checkNegativeFeedUnreads(count: Int): Int {
            if (count < 0) {
                Log.w(javaClass.name, "Negative unread count found and rounded up to zero.")
                return 0
            }
            return count
        }

        override fun onCleared() {
            loader.close()
            super.onCleared()
        }

        private data class LoadRequest(val cancellationSignal: CancellationSignal, val requestedAtNanos: Long)

        private data class Snapshot(
            val folders: FolderQueryResult,
            val feeds: FeedQueryResult,
            val socialFeeds: List<SocialFeed>,
            val savedStoryCounts: SavedStoryCountsQueryResult,
            val savedSearches: List<SavedSearch>,
            val requestedAtNanos: Long,
        )
    }
