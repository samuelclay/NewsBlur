package com.newsblur.repository

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Story
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.ReadingAction
import com.newsblur.util.doLocal
import javax.inject.Inject

class StoryRepositoryImpl
@Inject constructor(
        private val prefsRepo: PrefsRepo,
        private val dbHelper: BlurDatabaseHelper,
) : StoryRepository {

    override fun likeComment(story: Story, commentUserId: String?) {
        val ra = ReadingAction.LikeComment(story.id, commentUserId, story.feedId)
        dbHelper.enqueueAction(ra)
        ra.doLocal(dbHelper, prefsRepo)
    }

    override fun unlikeComment(story: Story, commentUserId: String?) {
        val ra = ReadingAction.UnlikeComment(story.id, commentUserId, story.feedId)
        dbHelper.enqueueAction(ra)
        ra.doLocal(dbHelper, prefsRepo)
    }

    override suspend fun shareStory(story: Story, comment: String, sourceUserIdString: String?) {
        val sourceUserId = story.sourceUserId ?: sourceUserIdString
        val ra = ReadingAction.ShareStory(story.storyHash, story.id, story.feedId, sourceUserId, comment)
        dbHelper.enqueueAction(ra)
        ra.doLocal(dbHelper, prefsRepo)
    }

    override suspend fun unshareStory(story: Story) {
        val ra = ReadingAction.UnshareStory(story.storyHash, story.id, story.feedId)
        dbHelper.enqueueAction(ra)
        ra.doLocal(dbHelper, prefsRepo)
    }

    override suspend fun setStoryReadStateExternal(storyHash: String, read: Boolean) {
        val ra = if (read) ReadingAction.MarkStoryRead(storyHash)
        else ReadingAction.MarkStoryUnread(storyHash)
        dbHelper.enqueueAction(ra)
    }
}