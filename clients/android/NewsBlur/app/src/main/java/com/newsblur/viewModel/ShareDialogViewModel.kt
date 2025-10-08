package com.newsblur.viewModel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.newsblur.domain.Story
import com.newsblur.repository.StoryRepository
import com.newsblur.service.NbSyncManager.UPDATE_SOCIAL
import com.newsblur.service.NbSyncManager.UPDATE_STORY
import com.newsblur.util.FeedUtils
import com.newsblur.util.FeedUtils.Companion.triggerSync
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@HiltViewModel
class ShareDialogViewModel
@Inject constructor(
        private val feedUtils: FeedUtils,
        private val storyRepository: StoryRepository,
) : ViewModel() {

    fun shareStory(context: Context, story: Story, comment: String, sourceUserIdString: String?) {
        viewModelScope.launch(Dispatchers.IO) {
            storyRepository.shareStory(story, comment, sourceUserIdString)
            withContext(Dispatchers.Main) {
                feedUtils.syncUpdateStatus(UPDATE_SOCIAL or UPDATE_STORY)
                triggerSync(context)
            }
        }
    }

    fun unshareStory(context: Context, story: Story) {
        viewModelScope.launch(Dispatchers.IO) {
            storyRepository.unshareStory(story)
            withContext(Dispatchers.Main) {
                feedUtils.syncUpdateStatus(UPDATE_SOCIAL or UPDATE_STORY)
                triggerSync(context)
            }
        }
    }
}