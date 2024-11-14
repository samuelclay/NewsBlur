package com.newsblur.viewModel

import android.database.Cursor
import android.os.CancellationSignal
import android.os.OperationCanceledException
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.util.CursorFilters
import com.newsblur.util.FeedSet
import com.newsblur.util.Log
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class StoriesViewModel
@Inject constructor(private val dbHelper: BlurDatabaseHelper): ViewModel() {

    private val cancellationSignal = CancellationSignal()
    private val _activeStoriesLiveData = MutableLiveData<Cursor>()
    val activeStoriesLiveData: LiveData<Cursor> = _activeStoriesLiveData

    fun getActiveStories(fs: FeedSet, cursorFilters: CursorFilters) {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                dbHelper.getActiveStoriesCursor(fs, cursorFilters, cancellationSignal).let {
                    _activeStoriesLiveData.postValue(it)
                }
            } catch (e: OperationCanceledException) {
                Log.e(this.javaClass.name, "Caught ${e.javaClass.name} in getActiveStories.")
            }
        }
    }

    override fun onCleared() {
        cancellationSignal.cancel()
        super.onCleared()
    }
}