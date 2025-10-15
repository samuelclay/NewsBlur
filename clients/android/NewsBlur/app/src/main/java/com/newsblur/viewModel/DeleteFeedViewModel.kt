package com.newsblur.viewModel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.repository.FeedRepository
import com.newsblur.service.NbSyncManager.UPDATE_METADATA
import com.newsblur.util.FeedUtils
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class DeleteFeedViewModel
    @Inject
    constructor(
        private val feedUtils: FeedUtils,
        private val feedRepository: FeedRepository,
    ) : ViewModel() {
        fun deleteFeed(
            feedId: String?,
            folderName: String?,
        ) {
            viewModelScope.launch(Dispatchers.IO) {
                feedRepository.deleteFeed(feedId, folderName)
                feedUtils.syncUpdateStatus(UPDATE_METADATA)
            }
        }

        fun deleteSavedSearch(
            feedId: String,
            query: String,
        ) {
            viewModelScope.launch(Dispatchers.IO) {
                feedRepository
                    .deleteSavedSearch(feedId, query)
                    .onSuccess {
                        feedUtils.syncUpdateStatus(UPDATE_METADATA)
                    }
            }
        }

        fun deleteSocialFeed(userId: String) {
            viewModelScope.launch(Dispatchers.IO) {
                feedRepository.deleteSocialFeed(userId)
                feedUtils.syncUpdateStatus(UPDATE_METADATA)
            }
        }
    }
