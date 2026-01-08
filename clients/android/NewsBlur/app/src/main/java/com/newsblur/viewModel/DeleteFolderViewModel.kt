package com.newsblur.viewModel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.network.FolderApi
import com.newsblur.service.SyncServiceState
import com.newsblur.util.AppConstants
import com.newsblur.util.FeedUtils.Companion.triggerSync
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@HiltViewModel
class DeleteFolderViewModel
    @Inject
    constructor(
        private val folderApi: FolderApi,
        private val syncServiceState: SyncServiceState,
        @param:ApplicationContext private val context: Context,
    ) : ViewModel() {
        sealed interface UiState {
            data object Confirm : UiState

            data object Loading : UiState

            data object Done : UiState
        }

        private val _uiState = MutableStateFlow<UiState>(UiState.Confirm)
        val uiState: StateFlow<UiState> = _uiState.asStateFlow()

        fun deleteFolder(
            folderName: String,
            folderParent: String?,
        ) {
            val inFolder =
                if (!folderParent.isNullOrEmpty() && folderParent != AppConstants.ROOT_FOLDER) {
                    folderParent
                } else {
                    ""
                }

            viewModelScope.launch(Dispatchers.IO) {
                _uiState.emit(UiState.Loading)
                try {
                    val response = folderApi.deleteFolder(folderName, inFolder)
                    if (!response.isError) {
                        withContext(Dispatchers.Main) {
                            syncServiceState.forceFeedsFolders()
                            triggerSync(context)
                        }
                    }
                } catch (_: Throwable) {
                } finally {
                    _uiState.emit(UiState.Done)
                }
            }
        }
    }
