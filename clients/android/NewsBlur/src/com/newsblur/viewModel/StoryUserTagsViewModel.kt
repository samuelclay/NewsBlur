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

class StoryUserTagsViewModel : ViewModel() {

    private val cancellationSignal = CancellationSignal()
    private val _savedStoryCountsLiveData = MutableLiveData<Cursor>()
    val savedStoryCountsLiveData: LiveData<Cursor> = _savedStoryCountsLiveData

    fun getSavedStoryCounts() {
        viewModelScope.launch(Dispatchers.IO) {
            val cursor = FeedUtils.dbHelper!!.getSavedStoryCountsCursor(cancellationSignal)
            _savedStoryCountsLiveData.postValue(cursor)
        }
    }

    override fun onCleared() {
        cancellationSignal.cancel()
        super.onCleared()
    }
}