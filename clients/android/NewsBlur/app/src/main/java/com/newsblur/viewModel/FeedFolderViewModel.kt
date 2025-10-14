package com.newsblur.viewModel

import android.os.CancellationSignal
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Feed
import com.newsblur.domain.Folder
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class FeedFolderViewModel
    @Inject
    constructor(
        private val dbHelper: BlurDatabaseHelper,
    ) : ViewModel() {
        private val cancellationSignal = CancellationSignal()

        private val _feedFolderData = MutableStateFlow(FeedFolderData(emptyList(), emptyList()))
        val feedFolderData = _feedFolderData.asStateFlow()

        fun getData() {
            viewModelScope.launch(Dispatchers.IO) {
                val folders =
                    dbHelper.getFoldersCursor(cancellationSignal).use { cursor ->
                        generateSequence { if (cursor.moveToNext()) Folder.fromCursor(cursor) else null }
                            .filter { it.feedIds.isNotEmpty() }
                            .sortedWith { o1, o2 -> Folder.compareFolderNames(o1.flatName(), o2.flatName()) }
                            .toList()
                    }

                val feeds =
                    dbHelper.getFeedsCursor(cancellationSignal).use { cursor ->
                        generateSequence { if (cursor.moveToNext()) Feed.fromCursor(cursor) else null }
                            .toList()
                    }

                _feedFolderData.emit(FeedFolderData(folders, feeds))
            }
        }

        override fun onCleared() {
            cancellationSignal.cancel()
            super.onCleared()
        }
    }

data class FeedFolderData(
    val folders: List<Folder>,
    val feeds: List<Feed>,
)
