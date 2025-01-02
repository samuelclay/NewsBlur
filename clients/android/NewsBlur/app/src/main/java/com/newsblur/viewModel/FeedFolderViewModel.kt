package com.newsblur.viewModel

import android.os.CancellationSignal
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Feed
import com.newsblur.domain.Folder
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class FeedFolderViewModel
@Inject constructor(private val dbHelper: BlurDatabaseHelper) : ViewModel() {

    private val cancellationSignal = CancellationSignal()

    private val _folders = MutableLiveData<List<Folder>>()
    val folders: LiveData<List<Folder>> = _folders
    private val _feeds = MutableLiveData<List<Feed>>()
    val feedsLiveData: LiveData<List<Feed>> = _feeds

    fun getData() {
        viewModelScope.launch(Dispatchers.IO) {
            launch {
                dbHelper.getFoldersCursor(cancellationSignal).use { cursor ->
                    val folders = mutableListOf<Folder>()
                    while (cursor.moveToNext()) {
                        val folder = Folder.fromCursor(cursor)
                        if (folder.feedIds.isNotEmpty()) {
                            folders.add(folder)
                        }
                    }
                    _folders.postValue(folders)
                }
            }

            getFeeds()
        }
    }

    fun getFeeds() {
        viewModelScope.launch(Dispatchers.IO) {
            dbHelper.getFeedsCursor(cancellationSignal).use { cursor ->
                val feeds = mutableListOf<Feed>()
                while (cursor.moveToNext()) {
                    val feed = Feed.fromCursor(cursor)
                    feeds.add(feed)
                }
                _feeds.postValue(feeds)
            }
        }
    }

    override fun onCleared() {
        cancellationSignal.cancel()
        super.onCleared()
    }
}