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
class StoryUserTagsViewModel
@Inject constructor(private val dbHelper: BlurDatabaseHelper): ViewModel() {

    private val cancellationSignal = CancellationSignal()
    private val _savedStoryCountsLiveData = MutableLiveData<Cursor>()
    val savedStoryCountsLiveData: LiveData<Cursor> = _savedStoryCountsLiveData

    fun getSavedStoryCounts() {
        viewModelScope.launch(Dispatchers.IO) {
            val cursor = dbHelper.getSavedStoryCountsCursor(cancellationSignal)
            _savedStoryCountsLiveData.postValue(cursor)
        }
    }

    override fun onCleared() {
        cancellationSignal.cancel()
        super.onCleared()
    }
}