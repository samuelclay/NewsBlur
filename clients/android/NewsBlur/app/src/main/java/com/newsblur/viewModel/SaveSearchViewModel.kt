package com.newsblur.viewModel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.repository.FeedRepository
import com.newsblur.service.SyncServiceState
import com.newsblur.util.FeedUtils.Companion.triggerSync
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@HiltViewModel
class SaveSearchViewModel
    @Inject
    constructor(
        private val feedRepository: FeedRepository,
        private val syncServiceState: SyncServiceState,
    ) : ViewModel() {
        fun saveSearch(
            context: Context,
            feedId: String,
            query: String,
        ) {
            viewModelScope.launch(Dispatchers.IO) {
                feedRepository
                    .saveSearch(feedId, query)
                    .onSuccess {
                        withContext(Dispatchers.Main) {
                            syncServiceState.forceFeedsFolders()
                            triggerSync(context)
                        }
                    }
            }
        }
    }
