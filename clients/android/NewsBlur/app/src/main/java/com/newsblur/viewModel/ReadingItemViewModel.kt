package com.newsblur.viewModel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.database.DatabaseConstants
import com.newsblur.network.APIConstants.NULL_STORY_TEXT
import com.newsblur.network.APIManager
import com.newsblur.util.FeedUtils
import com.newsblur.util.FeedUtils.Companion.inferFeedId
import com.newsblur.util.Log
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ReadingItemViewModel
@Inject constructor(
        @ApplicationContext private val context: Context,
        private val database: BlurDatabaseHelper,
        private val apiManager: APIManager,
        private val feedUtils: FeedUtils,
) : ViewModel() {

    private val _readingPayload = MutableStateFlow<ReadingPayload>(Idle)
    val readingPayload = _readingPayload.asStateFlow()

    private val _storyHighlightsUpdate = MutableSharedFlow<List<String>>()
    val storyHighlightsUpdate = _storyHighlightsUpdate.asSharedFlow()

    fun loadOriginalText(hash: String) {
        viewModelScope.launch(Dispatchers.IO) {
            val result = database.getStoryText(hash)
            if (result != null) {
                _readingPayload.emit(StoryOriginalText(result))
            } else {
                val response = apiManager.getStoryText(inferFeedId(hash), hash)
                val text = when {
                    response == null || response.originalText == null -> {
                        // a null value in an otherwise valid response to this call indicates a fatal
                        // failure to extract text and should be recorded so the UI can inform the
                        // user and switch them back to a valid view mode
                        NULL_STORY_TEXT
                    }

                    response.originalText.length >= DatabaseConstants.MAX_TEXT_SIZE -> {
                        // this API can occasionally return story texts that are much too large to query
                        // from the DB. Stop insertion to prevent poisoning the DB and the cursor lifecycle
                        Log.w(ReadingItemViewModel::class.simpleName, "discarding too-large story text. hash " + hash + " size " + response.originalText.length)
                        NULL_STORY_TEXT
                    }

                    else -> response.originalText

                }

                if (text != NULL_STORY_TEXT) {
                    database.putStoryText(hash, text)
                }

                _readingPayload.emit(StoryOriginalText(text))
            }
        }
    }

    fun loadStoryContent(hash: String) {
        viewModelScope.launch(Dispatchers.IO) {
            val content = database.getStoryContent(hash)
            if (content != null) {
                _readingPayload.emit(StoryContent(content))
            } else {
                Log.w(ReadingItemViewModel::class.simpleName, "Couldn't find story content for existing story $hash.")
                _readingPayload.emit(NoStoryContent)
            }
        }
    }

    fun updateHighlights(
            highlight: String,
            storyHash: String,
            storyHighlights: MutableSet<String>,
    ) {
        viewModelScope.launch(Dispatchers.IO) {
            when (val payload = _readingPayload.value) {
                is StoryContent -> payload.content
                is StoryOriginalText -> payload.text
                else -> null
            }?.let { content ->
                val highlights = storyHighlights.apply {
                    if (contains(highlight)) {
                        remove(highlight)
                    } else {
                        add(highlight)
                    }
                }.toList()

                feedUtils.setStorySaved(
                        context = context,
                        storyHash = storyHash,
                        saved = true,
                        highlights = highlights,
                )
                _storyHighlightsUpdate.emit(highlights)
            }
        }
    }

    sealed interface ReadingPayload
    data class StoryContent(
            val content: String,
    ) : ReadingPayload

    data class StoryOriginalText(
            val text: String,
    ) : ReadingPayload

    data object Idle : ReadingPayload
    data object NoStoryContent : ReadingPayload
}