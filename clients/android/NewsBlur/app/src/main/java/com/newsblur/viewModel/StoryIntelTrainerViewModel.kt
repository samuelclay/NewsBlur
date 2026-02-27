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
class StoryIntelTrainerViewModel
    @Inject
    constructor(
        private val db: BlurDatabaseHelper,
        savedStateHandle: SavedStateHandle,
    ) : ViewModel() {
        private val feedId: String = savedStateHandle.get<String>("feedId")!!
        private val storyHash: String = savedStateHandle.get<String>("storyHash")!!

        private var pendingTitleTraining: Int? = null
        private var pendingTextTraining: Int? = null

        val uiState: LiveData<StoryIntelUiState> =
            liveData(Dispatchers.IO) {
                emit(StoryIntelUiState(loading = true))
                try {
                    val classifier: Classifier = db.getClassifierForFeed(feedId)
                    val storyText: String? = (
                        db.getStoryText(storyHash)
                            ?: db.getStoryContent(storyHash)
                    )
                    emit(StoryIntelUiState(loading = false, classifier = classifier, storyText = storyText))
                } catch (t: Throwable) {
                    emit(
                        StoryIntelUiState(
                            loading = false,
                            classifier = null,
                            storyText = null,
                            error = t.message ?: "error",
                        ),
                    )
                }
            }

        // public setters for the fragment to call when the user presses like/dislike/clear
        fun setPendingTitleTraining(value: Int?) {
            pendingTitleTraining = value
        }

        fun setPendingTextTraining(value: Int?) {
            pendingTextTraining = value
        }

        // called by the fragment when Save is pressed; returns the modified classifier (not persisted here)
        fun buildUpdatedClassifier(
            classifier: Classifier,
            titleSelection: String?,
            textSelection: String?,
        ): Classifier {
            pendingTitleTraining?.let { v ->
                if (!titleSelection.isNullOrBlank()) classifier.title[titleSelection] = v
            }
            pendingTextTraining?.let { v ->
                if (!textSelection.isNullOrBlank()) classifier.texts[textSelection] = v
            }
            return classifier
        }
    }

data class StoryIntelUiState(
    val loading: Boolean = true,
    val classifier: Classifier? = null,
    val storyText: String? = null,
    val error: String? = null,
)
