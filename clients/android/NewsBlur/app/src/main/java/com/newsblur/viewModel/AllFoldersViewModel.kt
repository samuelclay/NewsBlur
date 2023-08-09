package com.newsblur.viewModel

import android.database.Cursor
import android.os.CancellationSignal
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.database.BlurDatabaseHelper
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AllFoldersViewModel
@Inject constructor(private val dbHelper: BlurDatabaseHelper) : ViewModel() {

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
                dbHelper.getSocialFeedsCursor(cancellationSignal).let {
                    _socialFeeds.postValue(it)
                }
            }
            launch {
                dbHelper.getFoldersCursor(cancellationSignal).let {
                    _folders.postValue(it)
                    // get feeds after folders load
                    getFeeds()
                }
            }
            launch {
                dbHelper.getSavedStoryCountsCursor(cancellationSignal).let {
                    _savedStoryCounts.postValue(it)
                }
            }
            launch {
                dbHelper.getSavedSearchCursor(cancellationSignal).let {
                    _savedSearch.postValue(it)
                }
            }
        }
    }

    private fun getFeeds() {
        viewModelScope.launch(Dispatchers.IO) {
            launch {
                dbHelper.getFeedsCursor(cancellationSignal).let {
                    _feeds.postValue(it)
                }
            }
        }
    }

    override fun onCleared() {
        cancellationSignal.cancel()
        super.onCleared()
    }
}