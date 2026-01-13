package com.newsblur.viewModel

import android.os.CancellationSignal
import android.util.Log
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Collections
import javax.inject.Inject

@HiltViewModel
class AllFoldersViewModel
    @Inject
    constructor(
        private val dbHelper: BlurDatabaseHelper,
    ) : ViewModel() {
        private val cancellationSignal = CancellationSignal()

        // social feeds
        private val _socialFeeds = MutableLiveData<List<SocialFeed>>()
        val socialFeeds: LiveData<List<SocialFeed>> = _socialFeeds

        // folders
        private val _folders = MutableLiveData<FolderQueryResult>()
        val folders: LiveData<FolderQueryResult> = _folders

        // feeds
        private val _feeds = MutableLiveData<FeedQueryResult>()
        var feeds: LiveData<FeedQueryResult> = _feeds

        // saved story counts
        private val _savedStoryCounts = MutableLiveData<SavedStoryCountsQueryResult>()
        val savedStoryCounts: LiveData<SavedStoryCountsQueryResult> = _savedStoryCounts

        // saved search
        private val _savedSearch = MutableLiveData<List<SavedSearch>>()
        val savedSearch: LiveData<List<SavedSearch>> = _savedSearch

        fun getData() {
            viewModelScope.launch(Dispatchers.IO) {
                launch {
                    dbHelper.getSocialFeedsCursor(cancellationSignal).use { cursor ->
                        if (!cursor.isBeforeFirst) return@use
                        val socialFeedsOrdered = ArrayList<SocialFeed>(cursor.count)
                        while (cursor.moveToNext()) {
                            val sf = SocialFeed.fromCursor(cursor)
                            socialFeedsOrdered.add(sf)
                        }
                        _socialFeeds.postValue(socialFeedsOrdered)
                    }
                }
                launch {
                    dbHelper.getFoldersCursor(cancellationSignal).use { cursor ->
                        if (cursor.count < 1 || !cursor.isBeforeFirst) return@use
                        val folders = LinkedHashMap<String, Folder>(cursor.count)
                        val flatFolders = LinkedHashMap<String, Folder>(cursor.count)
                        while (cursor.moveToNext()) {
                            val folder = Folder.fromCursor(cursor)
                            folders[folder.name] = folder
                            flatFolders[folder.flatName()] = folder
                        }
                        _folders.postValue(FolderQueryResult(folders = folders, flatFolders = flatFolders))
                        // get feeds after folders load
                        getFeeds()
                    }
                }
                launch {
                    dbHelper.getSavedStoryCountsCursor(cancellationSignal).use { cursor ->
                        if (!cursor.isBeforeFirst) return@use
                        val starredCountsByTag = mutableListOf<StarredCount>()
                        val feedSavedCounts = mutableMapOf<String, Int>()
                        var savedStoriesTotalCount: Int? = null

                        while (cursor.moveToNext()) {
                            val sc = StarredCount.fromCursor(cursor)
                            if (sc.isTotalCount) {
                                savedStoriesTotalCount = sc.count
                            } else if (sc.tag != null) {
                                starredCountsByTag.add(sc)
                            } else if (sc.feedId != null) {
                                feedSavedCounts[sc.feedId] = sc.count
                            }
                        }

                        Collections.sort(starredCountsByTag, StarredCount.StarredCountComparatorByTag)
                        _savedStoryCounts.postValue(
                            SavedStoryCountsQueryResult(starredCountsByTag, feedSavedCounts, savedStoriesTotalCount),
                        )
                    }
                }
                launch {
                    dbHelper.getSavedSearchCursor(cancellationSignal).use { cursor ->
                        if (!cursor.isBeforeFirst) return@use
                        val savedSearches = mutableListOf<SavedSearch>()
                        while (cursor.moveToNext()) {
                            val savedSearch = SavedSearch.fromCursor(cursor)
                            savedSearches.add(savedSearch)
                        }
                        Collections.sort(savedSearches, SavedSearch.SavedSearchComparatorByTitle)
                        _savedSearch.postValue(savedSearches)
                    }
                }
            }
        }

        private fun getFeeds() {
            viewModelScope.launch(Dispatchers.IO) {
                dbHelper.getFeedsCursor(cancellationSignal).use { cursor ->
                    if (!cursor.isBeforeFirst) return@use
                    val feeds = LinkedHashMap<String, Feed>(cursor.count)
                    val feedNeutCounts = mutableMapOf<String, Int>()
                    val feedPosCounts = mutableMapOf<String, Int>()
                    var totalNeutCount = 0
                    var totalPosCount = 0
                    var totalActiveFeedCount = 0

                    while (cursor.moveToNext()) {
                        val f = Feed.fromCursor(cursor)
                        feeds[f.feedId] = f
                        if (f.active && f.positiveCount > 0) {
                            val pos: Int = checkNegativeFeedUnreads(f.positiveCount)
                            feedPosCounts[f.feedId] = pos
                            totalPosCount += pos
                        }
                        if (f.active && f.neutralCount > 0) {
                            val neut: Int = checkNegativeFeedUnreads(f.neutralCount)
                            feedNeutCounts.put(f.feedId, neut)
                            totalNeutCount += neut
                        }
                        if (f.active) {
                            totalActiveFeedCount++
                        }
                    }

                    val result =
                        FeedQueryResult(
                            feeds = feeds,
                            feedNeutCounts = feedNeutCounts,
                            feedPosCounts = feedPosCounts,
                            totalNeutCount = totalNeutCount,
                            totalPosCount = totalPosCount,
                            totalActiveFeedCount = totalActiveFeedCount,
                        )
                    _feeds.postValue(result)
                }
            }
        }

        /**
         * Utility method to filter out and carp about negative unread counts.  These tend to indicate
         * a problem in the app or API, but are very confusing to users.
         */
        private fun checkNegativeFeedUnreads(count: Int): Int {
            if (count < 0) {
                Log.w(javaClass.name, "Negative unread count found and rounded up to zero.")
                return 0
            }
            return count
        }

        override fun onCleared() {
            cancellationSignal.cancel()
            super.onCleared()
        }
    }
