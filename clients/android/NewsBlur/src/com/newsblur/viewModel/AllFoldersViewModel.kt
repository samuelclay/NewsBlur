package com.newsblur.viewModel

import android.database.Cursor
import android.os.CancellationSignal
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.util.FeedUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class AllFoldersViewModel : ViewModel() {

    private val cancellationSignal = CancellationSignal()

    // social feeds
    private val _socialFeeds = MutableLiveData<Cursor>()
    val socialFeeds: LiveData<Cursor> = _socialFeeds

    // folders
    private val _folders = MutableLiveData<Cursor>()
    val folders: LiveData<Cursor> = _folders

    // feeds
    private val _feeds = MutableLiveData<Cursor>()
    val feeds: LiveData<Cursor> = _feeds

    // saved story counts
    private val _savedStoryCounts = MutableLiveData<Cursor>()
    val savedStoryCounts: LiveData<Cursor> = _savedStoryCounts

    // saved search
    private val _savedSearch = MutableLiveData<Cursor>()
    val savedSearch: LiveData<Cursor> = _savedSearch

    fun getData() {
        viewModelScope.launch(Dispatchers.IO) {
            launch {
                FeedUtils.dbHelper!!.getSocialFeedsCursor(cancellationSignal).let {
                    _socialFeeds.postValue(it)
                }
            }
            launch {
                FeedUtils.dbHelper!!.getFoldersCursor(cancellationSignal).let {
                    _folders.postValue(it)
                }
            }
            launch {
                FeedUtils.dbHelper!!.getFeedsCursor(cancellationSignal).let {
                    _feeds.postValue(it)
                }
            }
            launch {
                FeedUtils.dbHelper!!.getSavedStoryCountsCursor(cancellationSignal).let {
                    _savedStoryCounts.postValue(it)
                }
            }
            launch {
                FeedUtils.dbHelper!!.getSavedSearchCursor(cancellationSignal).let {
                    _savedSearch.postValue(it)
                }
            }
        }
    }

    override fun onCleared() {
        cancellationSignal.cancel()
        super.onCleared()
    }
}