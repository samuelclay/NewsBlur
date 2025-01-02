package com.newsblur.viewModel

import android.os.CancellationSignal
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.StarredCount
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Collections
import javax.inject.Inject

@HiltViewModel
class StoryUserTagsViewModel
@Inject constructor(private val dbHelper: BlurDatabaseHelper) : ViewModel() {

    private val cancellationSignal = CancellationSignal()
    private val _savedStoryCountsLiveData = MutableLiveData<List<StarredCount>>()
    val savedStoryCountsLiveData: LiveData<List<StarredCount>> = _savedStoryCountsLiveData

    fun getSavedStoryCounts() {
        viewModelScope.launch(Dispatchers.IO) {
            dbHelper.getSavedStoryCountsCursor(cancellationSignal).use { cursor ->
                if (!cursor.isBeforeFirst) return@use
                val starredTags = mutableListOf<StarredCount>()
                while (cursor.moveToNext()) {
                    val sc = StarredCount.fromCursor(cursor)
                    if (sc.tag != null && !sc.isTotalCount) {
                        starredTags.add(sc)
                    }
                }
                Collections.sort(starredTags, StarredCount.StarredCountComparatorByTag)
                _savedStoryCountsLiveData.postValue(starredTags)
            }
        }
    }

    override fun onCleared() {
        cancellationSignal.cancel()
        super.onCleared()
    }
}