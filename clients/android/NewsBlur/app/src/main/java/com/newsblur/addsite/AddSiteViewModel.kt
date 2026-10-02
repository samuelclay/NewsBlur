package com.newsblur.addsite

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.domain.FeedResult
import com.newsblur.domain.Folder
import com.newsblur.domain.FolderHierarchy
import com.newsblur.network.FeedApi
import com.newsblur.network.FolderApi
import com.newsblur.network.FolderPath
import com.newsblur.util.AppConstants
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

data class AddSiteState(
    val query: String = "",
    val parent: String = AppConstants.ROOT_FOLDER,
    val newFolder: String = "",
    val creatingFolder: Boolean = false,
    val folders: List<Folder> = emptyList(),
    val results: List<FeedResult> = emptyList(),
    val searching: Boolean = false,
    val searched: Boolean = false,
    val submitting: Boolean = false,
    val error: String? = null,
    val completedFeedId: String? = null,
    val folderRevision: Int = 0,
)

@HiltViewModel
class AddSiteViewModel
    @Inject
    constructor(
        private val feedApi: FeedApi,
        private val folderApi: FolderApi,
        private val savedState: SavedStateHandle,
    ) : ViewModel() {
        internal var workerDispatcher: CoroutineDispatcher = Dispatchers.IO
        private val mutableState =
            MutableStateFlow(
                AddSiteState(
                    query = savedState["query"] ?: savedState["feed_url"] ?: "",
                    parent = savedState["parent"] ?: AppConstants.ROOT_FOLDER,
                    newFolder = savedState["new_folder"] ?: "",
                    creatingFolder = savedState["creating_folder"] ?: false,
                ),
            )
        val state = mutableState.asStateFlow()
        private var searchJob: Job? = null
        private var generation = 0

        init {
            search(mutableState.value.query)
        }

        fun setFolders(folders: List<Folder>) {
            mutableState.update { it.copy(folders = FolderHierarchy(folders).ordered) }
        }

        fun queryChanged(query: String) {
            if (state.value.submitting) return
            savedState["query"] = query
            mutableState.update { it.copy(query = query, error = null) }
            search(query)
        }

        fun chooseFolder(path: String) {
            savedState["parent"] = path
            mutableState.update { it.copy(parent = path, error = null) }
        }

        fun folderNameChanged(name: String) {
            savedState["new_folder"] = name
            mutableState.update { it.copy(newFolder = name, error = null) }
        }

        fun toggleNewFolder() {
            val visible = !state.value.creatingFolder
            savedState["creating_folder"] = visible
            mutableState.update { it.copy(creatingFolder = visible, error = null) }
        }

        private fun search(query: String) {
            searchJob?.cancel()
            val requestGeneration = ++generation
            val term = query.trim()
            mutableState.update { it.copy(results = emptyList(), searching = term.isNotEmpty(), searched = false) }
            if (term.isEmpty()) return
            searchJob =
                viewModelScope.launch {
                    delay(350)
                    try {
                        val results = withContext(workerDispatcher) { feedApi.searchForFeed(term) }
                        if (requestGeneration != generation) return@launch
                        mutableState.update {
                            it.copy(
                                results = results?.toList().orEmpty(),
                                searched = true,
                                error = if (results == null) "Couldn’t search sites. Check your connection and try again." else null,
                            )
                        }
                    } catch (cancelled: CancellationException) {
                        throw cancelled
                    } catch (error: Exception) {
                        if (requestGeneration == generation) {
                            mutableState.update { it.copy(error = "Couldn’t search sites. Check your connection and try again.") }
                        }
                    } finally {
                        if (requestGeneration == generation) mutableState.update { it.copy(searching = false) }
                    }
                }
        }

        fun submit(url: String = state.value.query.trim()) {
            val snapshot = state.value
            if (snapshot.submitting || snapshot.completedFeedId != null) return
            val folderName = snapshot.newFolder.trim()
            if (snapshot.creatingFolder && folderName.isEmpty()) {
                mutableState.update { it.copy(error = "Enter a name for the new folder.") }
                return
            }
            if (url.isBlank() && !snapshot.creatingFolder) return
            if (url != snapshot.query.trim()) {
                savedState["query"] = url
                mutableState.update { it.copy(query = url) }
            }
            searchJob?.cancel()
            generation++
            mutableState.update { it.copy(submitting = true, searching = false, error = null) }
            viewModelScope.launch {
                var destination = snapshot.parent
                try {
                    if (snapshot.creatingFolder) {
                        val response = withContext(workerDispatcher) { folderApi.addFolder(folderName, destination) }
                        if (response.isError) {
                            mutableState.update { it.copy(error = response.getErrorMessage("Couldn’t create the folder.")) }
                            return@launch
                        }
                        val folder =
                            Folder().apply {
                                name = folderName
                                parents = ArrayList(FolderPath.parts(destination))
                            }
                        destination = folder.flatName()
                        chooseFolder(destination)
                        folderNameChanged("")
                        savedState["creating_folder"] = false
                        // AddSiteViewModel.kt keeps a successful folder creation when a later feed request fails.
                        mutableState.update {
                            it.copy(
                                creatingFolder = false,
                                folders =
                                    FolderHierarchy(
                                        it.folders.filter { existing ->
                                            existing.flatName() != destination
                                        } + folder,
                                    ).ordered,
                                folderRevision = it.folderRevision + 1,
                            )
                        }
                        FolderPath.setFolders(state.value.folders)
                    }
                    if (url.isBlank()) return@launch
                    val response = withContext(workerDispatcher) { feedApi.addFeed(url, destination) }
                    if (response == null || response.isError || response.feed?.feedId == null) {
                        mutableState.update {
                            it.copy(
                                error =
                                    response?.getErrorMessage("Couldn’t add the site. Please try again.")
                                        ?: "Couldn’t add the site. Please try again.",
                            )
                        }
                    } else {
                        mutableState.update { it.copy(completedFeedId = response.feed.feedId) }
                    }
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (error: Exception) {
                    mutableState.update { it.copy(error = "Couldn’t finish adding. Check your connection and try again.") }
                } finally {
                    mutableState.update { it.copy(submitting = false) }
                }
            }
        }
    }
