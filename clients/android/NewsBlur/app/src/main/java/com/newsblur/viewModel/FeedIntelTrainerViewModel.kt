package com.newsblur.viewModel

import androidx.lifecycle.LiveData
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.liveData
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Classifier
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import javax.inject.Inject

@HiltViewModel
class FeedIntelTrainerViewModel
    @Inject
    constructor(
        private val db: BlurDatabaseHelper,
        savedStateHandle: SavedStateHandle,
    ) : ViewModel() {
        private val feedId: String =
            requireNotNull(savedStateHandle.get<String>("feedId")) {
                "Missing feedId in SavedStateHandle"
            }

        val uiState: LiveData<FeedIntelUiState> =
            liveData(Dispatchers.IO) {
                emit(FeedIntelUiState(loading = true))
                try {
                    val classifier = db.getClassifierForFeed(feedId)

                    // suggested tags/authors
                    val tags = db.getTagsForFeed(feedId).toMutableList()
                    for ((k, _) in classifier.tags) {
                        if (!tags.contains(k)) tags.add(k)
                    }

                    val authors = db.getAuthorsForFeed(feedId).toMutableList()
                    for ((k, _) in classifier.authors) {
                        if (!authors.contains(k)) authors.add(k)
                    }

                    emit(
                        FeedIntelUiState(
                            loading = false,
                            classifier = classifier,
                            tags = tags,
                            authors = authors,
                        ),
                    )
                } catch (t: Throwable) {
                    emit(FeedIntelUiState(loading = false, error = t.message ?: "error"))
                }
            }
    }

data class FeedIntelUiState(
    val loading: Boolean = true,
    val classifier: Classifier? = null,
    val tags: List<String> = emptyList(),
    val authors: List<String> = emptyList(),
    val error: String? = null,
)
