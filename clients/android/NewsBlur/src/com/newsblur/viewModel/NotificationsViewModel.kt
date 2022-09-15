package com.newsblur.viewModel

import android.content.Context
import android.database.Cursor
import android.os.CancellationSignal
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Feed
import com.newsblur.util.FeedUtils
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class NotificationsViewModel
@Inject constructor(
        private val dbHelper: BlurDatabaseHelper,
        private val feedUtils: FeedUtils,
        ) : ViewModel() {

    private val cancellationSignal = CancellationSignal()

    private val _feeds = MutableLiveData<Map<String, Feed>>()
    val feeds: LiveData<Map<String, Feed>> = _feeds

    init {
        loadFeeds()
    }

    fun updateFeed(context: Context, feed: Feed) {
        viewModelScope.launch(Dispatchers.IO) {
            feedUtils.updateFeedNotifications(context, feed)
        }
    }

    private fun loadFeeds() {
        viewModelScope.launch(Dispatchers.IO) {
            launch {
                val cursor = dbHelper.getFeedsCursor(cancellationSignal)
                val feeds = extractFeeds(cursor).filterValues(notificationFeedFilter)
                _feeds.postValue(feeds)
            }
        }
    }

    private fun extractFeeds(cursor: Cursor): Map<String, Feed> = buildMap {
        if (!cursor.isBeforeFirst) return@buildMap

        while (cursor.moveToNext()) {
            val feed = Feed.fromCursor(cursor)
            this[feed.feedId] = feed
        }
    }

    private val notificationFeedFilter: (Feed) -> Boolean = {
        it.active && !it.notificationFilter.isNullOrBlank()
    }

    override fun onCleared() {
        cancellationSignal.cancel()
        super.onCleared()
    }
}