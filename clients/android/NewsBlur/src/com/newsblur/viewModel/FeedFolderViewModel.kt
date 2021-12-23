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

class FeedFolderViewModel : ViewModel() {

    private val cancellationSignal = CancellationSignal()

    private val _folders = MutableLiveData<Cursor>()
    val foldersLiveData: LiveData<Cursor> = _folders
    private val _feeds = MutableLiveData<Cursor>()
    val feedsLiveData: LiveData<Cursor> = _feeds

    fun getData() {
        viewModelScope.launch(Dispatchers.IO) {
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
        }
    }

    fun getFeeds() {
        viewModelScope.launch(Dispatchers.IO) {
            FeedUtils.dbHelper!!.getFeedsCursor(cancellationSignal).let {
                _feeds.postValue(it)
            }
        }
    }

    override fun onCleared() {
        cancellationSignal.cancel()
        super.onCleared()
    }
}