package com.newsblur.util

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.text.TextUtils
import com.newsblur.NbApplication
import com.newsblur.R
import com.newsblur.activity.NbActivity
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Classifier
import com.newsblur.domain.Feed
import com.newsblur.domain.Story
import com.newsblur.fragment.ReadingActionConfirmationFragment
import com.newsblur.network.APIConstants
import com.newsblur.network.APIConstants.NULL_STORY_TEXT
import com.newsblur.network.FolderApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.service.NbSyncManager
import com.newsblur.service.NbSyncManager.UPDATE_METADATA
import com.newsblur.service.NbSyncManager.UPDATE_SOCIAL
import com.newsblur.service.NbSyncManager.UPDATE_STATUS
import com.newsblur.service.NbSyncManager.UPDATE_STORY
import com.newsblur.service.SyncService
import com.newsblur.service.SyncServiceState
import com.newsblur.util.FeedExt.disableNotification
import com.newsblur.util.FeedExt.setNotifyFocus
import com.newsblur.util.FeedExt.setNotifyUnread

class FeedUtils(
    private val dbHelper: BlurDatabaseHelper,
    private val folderApi: FolderApi,
    private val prefsRepo: PrefsRepo,
    private val syncServiceState: SyncServiceState,
) {
    // this is gross, but the feedset can't hold a folder title
    // without being mistaken for a folder feed.
    // The alternative is to pass it through alongside all instances
    // of the feedset
    @JvmField
    var currentFolderName: String? = null

    fun prepareReadingSession(
        fs: FeedSet?,
        resetFirst: Boolean,
    ) {
        NBScope.executeAsyncTask(
            doInBackground = {
                try {
                    if (resetFirst) syncServiceState.resetReadingSession(dbHelper)
                    fs?.let { feedSet ->
                        synchronized(syncServiceState.pendingFeedMutex) {
                            val cursorFilters = CursorFilters(prefsRepo, feedSet)
                            if (feedSet != dbHelper.getSessionFeedSet()) {
                                Log.d(FeedUtils::class.simpleName, "preparing new reading session")
                                // the next fetch will be the start of a new reading session; clear it so it
                                // will be re-primed
                                dbHelper.clearStorySession()
                                // don't just rely on the auto-prepare code when fetching stories, it might be called
                                // after we insert our first page and not trigger
                                dbHelper.prepareReadingSession(fs, cursorFilters.stateFilter, cursorFilters.readFilter)
                                // note which feedset we are loading so we can trigger another reset when it changes
                                dbHelper.sessionFeedSet = fs
                                NbSyncManager.submitUpdate(UPDATE_STORY or UPDATE_STATUS)
                            }
                        }
                    }
                } catch (_: Exception) {
                    // this is a UI hinting call and might fail if the DB is being reset, but that is fine
                }
            },
        )
    }

    fun setStorySaved(
        storyHash: String?,
        saved: Boolean,
        context: Context,
        highlights: List<String>,
    ) {
        val userTags =
            buildList {
                currentFolderName?.let { add(it) }
            }
        setStorySaved(storyHash, saved, context, highlights, userTags)
    }

    fun setStorySaved(
        story: Story,
        saved: Boolean,
        context: Context,
        highlights: List<String>,
        userTags: List<String>,
    ) {
        setStorySaved(story.storyHash, saved, context, highlights, userTags)
    }

    private fun setStorySaved(
        storyHash: String?,
        saved: Boolean,
        context: Context,
        highlights: List<String>,
        userTags: List<String>,
    ) {
        if (storyHash == null) {
            Log.w(FeedUtils::class.java.name, "setStorySaved: storyHash is null")
            return
        }

        NBScope.executeAsyncTask(
            doInBackground = {
                val ra =
                    if (saved) {
                        ReadingAction.SaveStory(storyHash, highlights, userTags)
                    } else {
                        ReadingAction.UnsaveStory(storyHash)
                    }
                ra.doLocal(dbHelper, prefsRepo)
                dbHelper.enqueueAction(ra)
            },
            onPostExecute = {
                syncUpdateStatus(UPDATE_STORY)
                triggerSync(context)
            },
        )
    }

    fun markStoryUnread(
        story: Story,
        context: Context,
    ) {
        NBScope.executeAsyncTask(
            doInBackground = {
                setStoryReadState(story, context, false)
            },
        )
    }

    fun markStoryAsRead(
        story: Story,
        context: Context,
    ) {
        NBScope.executeAsyncTask(
            doInBackground = {
                setStoryReadState(story, context, true)
            },
        )
    }

    private fun setStoryReadState(
        story: Story,
        context: Context,
        read: Boolean,
    ) {
        try {
            // this shouldn't throw errors, but crash logs suggest something is racing it for DB resources.
            // capture logs in hopes of finding the correlated action
            dbHelper.touchStory(story.storyHash)
        } catch (e: Exception) {
            Log.e(FeedUtils::class.java.name, "error touching story state in DB", e)
        }
        if (story.read == read) {
            return
        }

        // tell the sync service we need to mark read
        val ra =
            if (read) {
                ReadingAction.MarkStoryRead(story.storyHash)
            } else {
                ReadingAction.MarkStoryUnread(story.storyHash)
            }
        dbHelper.enqueueAction(ra)

        // update unread state and unread counts in the local DB
        val impactedFeeds = dbHelper.setStoryReadState(story, read)
        syncUpdateStatus(UPDATE_STORY)

        syncServiceState.addRecountCandidates(impactedFeeds)
        triggerSync(context)
    }

    fun markRead(
        activity: NbActivity,
        fs: FeedSet,
        olderThan: Long?,
        newerThan: Long?,
        choicesRid: Int,
    ) = markRead(activity, fs, olderThan, newerThan, choicesRid, null)

    /**
     * Marks some or all of the stories in a FeedSet as read for an activity, handling confirmation dialogues as necessary.
     */
    fun markRead(
        activity: NbActivity,
        fs: FeedSet,
        olderThan: Long?,
        newerThan: Long?,
        choicesRid: Int,
        callback: ReadingActionListener?,
    ) {
        val ra: ReadingAction =
            if (fs.isAllNormal && (olderThan != null || newerThan != null)) {
                // the mark-all-read API doesn't support range bounding, so we need to pass each and every
                // feed ID to the API instead.
                val newFeedSet = FeedSet.folder("all", dbHelper.allActiveFeeds)
                ReadingAction.MarkFeedRead(newFeedSet, olderThan, newerThan)
            } else {
                if (fs.isFolder) {
                    val feedIds = fs.multipleFeeds
                    val allActiveFeedIds = dbHelper.allActiveFeeds
                    val activeFeedIds: MutableSet<String> = HashSet()
                    activeFeedIds.addAll(feedIds)
                    activeFeedIds.retainAll(allActiveFeedIds)
                    val filteredFs = FeedSet.folder(fs.folderName, activeFeedIds)
                    ReadingAction.MarkFeedRead(filteredFs, olderThan, newerThan)
                } else {
                    ReadingAction.MarkFeedRead(fs, olderThan, newerThan)
                }
            }
        // is it okay to just do the mark? otherwise we will seek confirmation
        var doImmediate = true
        // if set, this message will be displayed instead of the options to actually mark read. used in
        // situations where marking all read is almost certainly not what the user wants to do
        var optionalOverrideMessage: String? = null
        if (olderThan != null || newerThan != null) {
            // if this is a range mark, check that option
            if (prefsRepo.isConfirmMarkRangeRead()) doImmediate = false
        } else {
            // if this is an all mark, check that option
            val confirmation = prefsRepo.getMarkAllReadConfirmation()
            if (confirmation.feedSetRequiresConfirmation(fs)) doImmediate = false
        }
        // marks hit all stories, even when filtering via search, so warn
        if (fs.searchQuery != null) {
            doImmediate = false
            optionalOverrideMessage = activity.resources.getString(R.string.search_mark_read_warning)
        }
        if (doImmediate) {
            doAction(ra, activity)
            callback?.onReadingActionCompleted()
        } else {
            val title: String? =
                when {
                    fs.isAllNormal -> {
                        activity.resources.getString(R.string.all_stories)
                    }

                    fs.isFolder -> {
                        fs.folderName
                    }

                    fs.isSingleSocial -> {
                        dbHelper.getSocialFeed(fs.singleSocialFeed.key)?.feedTitle ?: ""
                    }

                    else -> {
                        dbHelper.getFeed(fs.singleFeed)?.title ?: ""
                    }
                }
            val dialog = ReadingActionConfirmationFragment.newInstance(ra, title, optionalOverrideMessage, choicesRid, callback)
            dialog.show(activity.supportFragmentManager, "dialog")
        }
    }

    fun disableNotifications(
        context: Context,
        feed: Feed,
    ) {
        feed.disableNotification()
        updateFeedNotifications(context, feed)
    }

    fun enableUnreadNotifications(
        context: Context,
        feed: Feed,
    ) {
        feed.setNotifyUnread()
        updateFeedNotifications(context, feed)
    }

    fun enableFocusNotifications(
        context: Context,
        feed: Feed,
    ) {
        feed.setNotifyFocus()
        updateFeedNotifications(context, feed)
    }

    fun updateFeedNotifications(
        context: Context,
        feed: Feed,
    ) {
        NBScope.executeAsyncTask(
            doInBackground = {
                dbHelper.updateFeed(feed)
                val ra = ReadingAction.SetNotify(feed.feedId, feed.notificationTypes, feed.notificationFilter)
                doAction(ra, context)
            },
        )
    }

    fun doAction(
        ra: ReadingAction?,
        context: Context,
    ) {
        requireNotNull(ra) { "ReadingAction must not be null" }
        NBScope.executeAsyncTask(
            doInBackground = {
                dbHelper.enqueueAction(ra)
                val impact = ra.doLocal(dbHelper, prefsRepo)
                syncUpdateStatus(impact)
                triggerSync(context)
            },
        )
    }

    fun updateClassifier(
        feedId: String?,
        classifier: Classifier?,
        fs: FeedSet?,
        context: Context,
    ) {
        val ra = ReadingAction.UpdateIntel(feedId, classifier, fs)
        doAction(ra, context)
    }

    fun sendStoryUrl(
        story: Story?,
        context: Context,
    ) {
        if (story == null) return
        val intent = Intent(Intent.ACTION_SEND)
        intent.type = "text/plain"
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.putExtra(Intent.EXTRA_SUBJECT, story.title)
        intent.putExtra(Intent.EXTRA_TEXT, story.permalink)
        context.startActivity(Intent.createChooser(intent, "Send using"))
    }

    fun sendStoryFull(
        story: Story?,
        context: Context,
    ) {
        if (story == null) return
        var body = getStoryText(story.storyHash)
        if (body.isNullOrEmpty() || body == NULL_STORY_TEXT) {
            body = getStoryContent(story.storyHash)
        }
        val intent = Intent(Intent.ACTION_SEND)
        intent.type = "text/plain"
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.putExtra(Intent.EXTRA_SUBJECT, story.title)
        intent.putExtra(
            Intent.EXTRA_TEXT,
            String.format(context.resources.getString(R.string.send_full), story.title, story.permalink, UIUtils.fromHtml(body)),
        )
        context.startActivity(Intent.createChooser(intent, "Send using"))
    }

    fun replyToComment(
        storyId: String?,
        feedId: String?,
        commentUserId: String?,
        replyText: String?,
        context: Context,
    ) {
        val ra = ReadingAction.ReplyToComment(storyId, feedId, commentUserId, replyText)
        dbHelper.enqueueAction(ra)
        ra.doLocal(dbHelper, prefsRepo)
        syncUpdateStatus(UPDATE_SOCIAL)
        triggerSync(context)
    }

    fun updateReply(
        context: Context,
        story: Story,
        commentUserId: String?,
        replyId: String?,
        replyText: String?,
    ) {
        val ra = ReadingAction.EditReply(story.id, story.feedId, commentUserId, replyId, replyText)
        dbHelper.enqueueAction(ra)
        ra.doLocal(dbHelper, prefsRepo)
        syncUpdateStatus(UPDATE_SOCIAL)
        triggerSync(context)
    }

    fun deleteReply(
        context: Context,
        story: Story,
        commentUserId: String?,
        replyId: String?,
    ) {
        val ra = ReadingAction.DeleteReply(story.id, story.feedId, commentUserId, replyId)
        dbHelper.enqueueAction(ra)
        ra.doLocal(dbHelper, prefsRepo)
        syncUpdateStatus(UPDATE_SOCIAL)
        triggerSync(context)
    }

    fun moveFeedToFolders(
        context: Context,
        feedId: String?,
        toFolders: Set<String>,
        inFolders: Set<String>,
    ) {
        if (toFolders.isEmpty()) return
        NBScope.executeAsyncTask(
            doInBackground = {
                folderApi.moveFeedToFolders(feedId, toFolders, inFolders)
            },
            onPostExecute = {
                syncServiceState.forceFeedsFolders()
                triggerSync(context)
            },
        )
    }

    fun muteFeeds(
        context: Context,
        feedIds: Set<String>,
    ) {
        updateFeedActiveState(context, feedIds, false)
    }

    fun unmuteFeeds(
        context: Context,
        feedIds: Set<String>,
    ) {
        updateFeedActiveState(context, feedIds, true)
    }

    private fun updateFeedActiveState(
        context: Context,
        feedIds: Set<String>,
        active: Boolean,
    ) {
        NBScope.executeAsyncTask(
            doInBackground = {
                val activeFeeds = dbHelper.allActiveFeeds
                for (feedId in feedIds) {
                    if (active) {
                        activeFeeds.add(feedId)
                    } else {
                        activeFeeds.remove(feedId)
                    }
                }

                val ra: ReadingAction =
                    if (active) {
                        ReadingAction.UnmuteFeeds(activeFeeds, feedIds)
                    } else {
                        ReadingAction.MuteFeeds(activeFeeds, feedIds)
                    }

                dbHelper.enqueueAction(ra)
                ra.doLocal(dbHelper, prefsRepo)
            },
            onPostExecute = {
                syncUpdateStatus(UPDATE_METADATA)
                triggerSync(context)
            },
        )
    }

    fun instaFetchFeed(
        context: Context,
        feedId: String?,
    ) {
        val ra = ReadingAction.InstaFetch(feedId)
        dbHelper.enqueueAction(ra)
        ra.doLocal(dbHelper, prefsRepo)
        syncUpdateStatus(UPDATE_METADATA)
        triggerSync(context)
    }

    fun getStoryText(hash: String?): String? = dbHelper.getStoryText(hash)

    fun getStoryContent(hash: String?): String? = dbHelper.getStoryContent(hash)

    /**
     * Because story objects have to join on the feeds table to get feed metadata, there are times
     * where standalone stories are missing this info and it must be re-fetched.  This is costly
     * and should be avoided where possible.
     */
    fun getFeedTitle(feedId: String?): String? = dbHelper.getFeed(feedId)?.title

    fun getFeed(feedId: String?): Feed? = dbHelper.getFeed(feedId)

    fun openStatistics(
        context: Context?,
        prefsRepo: PrefsRepo,
        feedId: String,
    ) {
        val url = APIConstants.buildUrl(APIConstants.PATH_FEED_STATISTICS + feedId)
        UIUtils.handleUri(context, prefsRepo, Uri.parse(url))
    }

    fun syncUpdateStatus(update: Int) {
        if (NbApplication.isAppForeground) {
            NbSyncManager.submitUpdate(update)
        }
    }

    companion object {
        @JvmStatic
        fun triggerSync(context: Context) {
            // NB: when our minSDKversion hits 28, it could be possible to start the service via the JobScheduler
            // with the setImportantWhileForeground() flag via an enqueue() and get rid of all legacy startService
            // code paths
            try {
                val i = Intent(context, SyncService::class.java)
                context.startService(i)
            } catch (e: IllegalStateException) {
                // BackgroundServiceStartNotAllowedException
                Log.e(this, "triggerSync error: ${e.message}")
            }
        }

        /**
         * Infer the feed ID for a story from the story's hash.  Useful for APIs
         * that takes a feed ID and story ID and only the story hash is known.
         *
         * TODO: this has a smell to it. can't all APIs just accept story hashes?
         */
        @JvmStatic
        fun inferFeedId(storyHash: String?): String? {
            val parts = TextUtils.split(storyHash, ":")
            return if (parts.size != 2) null else parts[0]
        }

        /**
         * Copy of TextUtils.equals because of Java for unit tests
         */
        @JvmStatic
        fun textUtilsEquals(
            a: CharSequence?,
            b: CharSequence?,
        ): Boolean {
            if (a === b) return true
            return if (a != null && b != null && a.length == b.length) {
                if (a is String && b is String) {
                    a == b
                } else {
                    for (i in a.indices) {
                        if (a[i] != b[i]) return false
                    }
                    true
                }
            } else {
                false
            }
        }
    }
}
