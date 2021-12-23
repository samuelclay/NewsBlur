package com.newsblur.viewModel

import android.database.Cursor
import android.os.CancellationSignal
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class StoriesViewModel : ViewModel() {

    private val cancellationSignal = CancellationSignal()
    private val _activeStoriesLiveData = MutableLiveData<Cursor>()
    val activeStoriesLiveData: LiveData<Cursor> = _activeStoriesLiveData

    fun getActiveStories(fs: FeedSet) {
        viewModelScope.launch(Dispatchers.IO) {
            FeedUtils.dbHelper!!.getActiveStoriesCursor(fs, cancellationSignal).let {
                _activeStoriesLiveData.postValue(it)
            }
        }
    }

    override fun onCleared() {
        cancellationSignal.cancel()
        super.onCleared()
    }
}