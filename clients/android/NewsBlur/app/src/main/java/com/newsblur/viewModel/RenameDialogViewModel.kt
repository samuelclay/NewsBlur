package com.newsblur.viewModel

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.network.FeedApi
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
class RenameDialogViewModel
    @Inject
    constructor(
        private val feedApi: FeedApi,
        private val folderApi: FolderApi,
        private val syncServiceState: SyncServiceState,
        @param:ApplicationContext private val context: Context,
    ) : ViewModel() {
        sealed interface UiState {
            data object Idle : UiState

            data object Loading : UiState

            data object Done : UiState

            data object ValidationError : UiState
        }

        private val _uiState = MutableStateFlow<UiState>(UiState.Idle)
        val uiState: StateFlow<UiState> = _uiState.asStateFlow()

        var text by mutableStateOf("")
            private set

        fun setInitialText(value: String) {
            if (text.isEmpty()) text = value
        }

        fun onTextChanged(new: String) {
            text = new
            if (_uiState.value is UiState.ValidationError && new.isNotBlank()) {
                _uiState.value = UiState.Idle
            }
        }

        fun renameFeed(feedId: String) {
            val newName = text.trim()
            if (newName.isEmpty()) {
                _uiState.value = UiState.ValidationError
                return
            }

            viewModelScope.launch(Dispatchers.IO) {
                _uiState.emit(UiState.Loading)
                try {
                    val response = feedApi.renameFeed(feedId, newName)
                    if (response != null && !response.isError) {
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

        fun renameFolder(
            oldName: String,
            parent: String?,
        ) {
            val newName = text.trim()
            if (newName.isEmpty()) {
                _uiState.value = UiState.ValidationError
                return
            }

            val inFolder =
                if (!parent.isNullOrEmpty() && parent != AppConstants.ROOT_FOLDER) parent else ""

            viewModelScope.launch(Dispatchers.IO) {
                _uiState.emit(UiState.Loading)
                try {
                    val response = folderApi.renameFolder(oldName, newName, inFolder)
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
