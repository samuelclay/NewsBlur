package com.newsblur.util

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.text.TextUtils
import com.newsblur.NbApplication
import com.newsblur.R
import com.newsblur.activity.NbActivity
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.*
import com.newsblur.fragment.ReadingActionConfirmationFragment
import com.newsblur.network.APIConstants
import com.newsblur.network.APIManager
import com.newsblur.service.NBSyncService
import com.newsblur.service.NBSyncReceiver
import com.newsblur.service.NBSyncReceiver.Companion.UPDATE_METADATA
import com.newsblur.service.NBSyncReceiver.Companion.UPDATE_SOCIAL
import com.newsblur.service.NBSyncReceiver.Companion.UPDATE_STORY
import java.util.*

object FeedUtils {

    // these are app-level singletons stored here for convenience. however, they
    // cannot be created lazily or via static init, they have to be created when
    // the main app context is created and it offers a reference
    @JvmField
    var dbHelper: BlurDatabaseHelper? = null

    @JvmField
    var iconLoader: ImageLoader? = null

    @JvmField
    var thumbnailLoader: ImageLoader? = null

    var storyImageCache: FileCache? = null

    // this is gross, but the feedset can't hold a folder title
    // without being mistaken for a folder feed.
    // The alternative is to pass it through alongside all instances
    // of the feedset
    @JvmField
    var currentFolderName: String? = null

    @JvmStatic
    fun offerInitContext(context: Context) {
        if (dbHelper == null) {
            dbHelper = BlurDatabaseHelper(context.applicationContext)
        }
        if (iconLoader == null) {
            iconLoader = ImageLoader.asIconLoader(context.applicationContext)
        }
        if (storyImageCache == null) {
            storyImageCache = FileCache.asStoryImageCache(context.applicationContext)
        }
        if (thumbnailLoader == null) {
            thumbnailLoader = ImageLoader.asThumbnailLoader(context.applicationContext, storyImageCache)
        }
    }

    @JvmStatic
    fun triggerSync(c: Context) {
        // NB: when our minSDKversion hits 28, it could be possible to start the service via the JobScheduler
        // with the setImportantWhileForeground() flag via an enqueue() and get rid of all legacy startService
        // code paths
        val i = Intent(c, NBSyncService::class.java)
        c.startService(i)
    }

    @JvmStatic
    fun dropAndRecreateTables() {
        dbHelper!!.dropAndRecreateTables()
    }

    @JvmStatic
    fun prepareReadingSession(fs: FeedSet?, resetFirst: Boolean) {
        NBScope.executeAsyncTask(
                doInBackground = {
                    try {
                        if (resetFirst) NBSyncService.resetReadingSession(dbHelper)
                        NBSyncService.prepareReadingSession(dbHelper, fs)
                    } catch (e: Exception) {
                        // this is a UI hinting call and might fail if the DB is being reset, but that is fine
                    }
                }
        )
    }

    fun setStorySaved(storyHash: String?, saved: Boolean, context: Context) {
        val userTags: MutableList<String?> = ArrayList()
        if (currentFolderName != null) {
            userTags.add(currentFolderName)
        }
        setStorySaved(storyHash, saved, context, userTags)
    }

    @JvmStatic
    fun setStorySaved(story: Story, saved: Boolean, context: Context, userTags: List<String?>?) {
        setStorySaved(story.storyHash, saved, context, userTags)
    }

    private fun setStorySaved(storyHash: String?, saved: Boolean, context: Context, userTags: List<String?>?) {
        NBScope.executeAsyncTask(
                doInBackground = {
                    val ra = if (saved) ReadingAction.saveStory(storyHash, userTags) else ReadingAction.unsaveStory(storyHash)
                    ra.doLocal(dbHelper)
                    syncUpdateStatus(context, UPDATE_STORY)
                    dbHelper!!.enqueueAction(ra)
                    triggerSync(context)
                }
        )
    }

    @JvmStatic
    fun deleteSavedSearch(feedId: String?, query: String?, context: Context) {
        NBScope.executeAsyncTask(
                doInBackground = {
                    APIManager(context).deleteSearch(feedId, query)
                },
                onPostExecute = { newsBlurResponse ->
                    if (!newsBlurResponse.isError) {
                        dbHelper!!.deleteSavedSearch(feedId, query)
                        syncUpdateStatus(context, UPDATE_METADATA)
                    }
                }
        )
    }

    @JvmStatic
    fun saveSearch(feedId: String?, query: String?, context: Context, apiManager: APIManager) {
        NBScope.executeAsyncTask(
                doInBackground = {
                    apiManager.saveSearch(feedId, query)
                },
                onPostExecute = { newsBlurResponse ->
                    if (!newsBlurResponse.isError) {
                        NBSyncService.forceFeedsFolders()
                        triggerSync(context)
                    }
                }
        )
    }

    @JvmStatic
    fun deleteFeed(feedId: String?, folderName: String?, context: Context) {
        NBScope.executeAsyncTask(
                doInBackground = {
                    APIManager(context).deleteFeed(feedId, folderName)
                },
                onPostExecute = {
                    // TODO: we can't check result.isError() because the delete call sets the .message property on all calls. find a better error check
                    dbHelper!!.deleteFeed(feedId)
                    syncUpdateStatus(context, UPDATE_METADATA)
                }
        )
    }

    @JvmStatic
    fun deleteSocialFeed(userId: String?, context: Context) {
        NBScope.executeAsyncTask(
                doInBackground = {
                    APIManager(context).unfollowUser(userId)
                },
                onPostExecute = {
                    // TODO: we can't check result.isError() because the delete call sets the .message property on all calls. find a better error check
                    dbHelper!!.deleteSocialFeed(userId)
                    syncUpdateStatus(context, UPDATE_METADATA)
                }
        )
    }

    @JvmStatic
    fun deleteFolder(folderName: String?, inFolder: String?, context: Context, apiManager: APIManager) {
        NBScope.executeAsyncTask(
                doInBackground = {
                    apiManager.deleteFolder(folderName, inFolder)
                },
                onPostExecute = { result ->
                    if (!result.isError) {
                        NBSyncService.forceFeedsFolders()
                        triggerSync(context)
                    }
                }
        )
    }

    @JvmStatic
    fun syncOfflineStories(context: Context) {
        dbHelper!!.deleteStories()
        NBSyncService.forceFeedsFolders()
        triggerSync(context)
    }

    @JvmStatic
    fun renameFolder(folderName: String?, newFolderName: String?, inFolder: String?, context: Context, apiManager: APIManager) {
        NBScope.executeAsyncTask(
                doInBackground = {
                    apiManager.renameFolder(folderName, newFolderName, inFolder)
                },
                onPostExecute = { result ->
                    if (!result.isError) {
                        NBSyncService.forceFeedsFolders()
                        triggerSync(context)
                    }
                }
        )
    }

    @JvmStatic
    fun markStoryUnread(story: Story, context: Context) {
        NBScope.executeAsyncTask(
                doInBackground = {
                    setStoryReadState(story, context, false)
                }
        )
    }

    @JvmStatic
    fun markStoryAsRead(story: Story, context: Context) {
        NBScope.executeAsyncTask(
                doInBackground = {
                    setStoryReadState(story, context, true)
                }
        )
    }

    private fun setStoryReadState(story: Story, context: Context, read: Boolean) {
        try {
            // this shouldn't throw errors, but crash logs suggest something is racing it for DB resources.
            // capture logs in hopes of finding the correlated action
            dbHelper!!.touchStory(story.storyHash)
        } catch (e: Exception) {
            Log.e(FeedUtils::class.java.name, "error touching story state in DB", e)
        }
        if (story.read == read) {
            return
        }

        // tell the sync service we need to mark read
        val ra = if (read) ReadingAction.markStoryRead(story.storyHash) else ReadingAction.markStoryUnread(story.storyHash)
        dbHelper!!.enqueueAction(ra)

        // update unread state and unread counts in the local DB
        val impactedFeeds = dbHelper!!.setStoryReadState(story, read)
        syncUpdateStatus(context, UPDATE_STORY)

        NBSyncService.addRecountCandidates(impactedFeeds)
        triggerSync(context)
    }

    /**
     * Mark a story (un)read when only the hash is known. This can and will cause a brief mismatch in
     * unread counts, or a longer mismatch if offline.  This method should only be used from outside
     * the app, such as from a notifiation handler.  You must use setStoryReadState(Story, Context, boolean)
     * when calling from within the UI.
     */
    fun setStoryReadStateExternal(storyHash: String?, context: Context, read: Boolean) {
        val ra = if (read) ReadingAction.markStoryRead(storyHash) else ReadingAction.markStoryUnread(storyHash)
        dbHelper!!.enqueueAction(ra)

        val feedId = inferFeedId(storyHash)
        val impactedFeed = FeedSet.singleFeed(feedId)
        NBSyncService.addRecountCandidates(impactedFeed)

        triggerSync(context)
    }

    /**
     * Marks some or all of the stories in a FeedSet as read for an activity, handling confirmation dialogues as necessary.
     */
    @JvmStatic
    fun markRead(activity: NbActivity, fs: FeedSet, olderThan: Long?, newerThan: Long?, choicesRid: Int, finishAfter: Boolean) {
        val ra: ReadingAction = if (fs.isAllNormal && (olderThan != null || newerThan != null)) {
            // the mark-all-read API doesn't support range bounding, so we need to pass each and every
            // feed ID to the API instead.
            val newFeedSet = FeedSet.folder("all", dbHelper!!.allActiveFeeds)
            ReadingAction.markFeedRead(newFeedSet, olderThan, newerThan)
        } else {
            if (fs.singleFeed != null) {
                if (!fs.isMuted) {
                    ReadingAction.markFeedRead(fs, olderThan, newerThan)
                } else {
                    // this should not be possible if appropriate menus have been altered. 
                    Log.w(activity, "disregarding mark-read for muted feed.")
                    return
                }
            } else if (fs.isFolder) {
                val feedIds = fs.multipleFeeds
                val allActiveFeedIds = dbHelper!!.allActiveFeeds
                val activeFeedIds: MutableSet<String> = HashSet()
                activeFeedIds.addAll(feedIds)
                activeFeedIds.retainAll(allActiveFeedIds)
                val filteredFs = FeedSet.folder(fs.folderName, activeFeedIds)
                ReadingAction.markFeedRead(filteredFs, olderThan, newerThan)
            } else {
                ReadingAction.markFeedRead(fs, olderThan, newerThan)
            }
        }
        // is it okay to just do the mark? otherwise we will seek confirmation
        var doImmediate = true
        // if set, this message will be displayed instead of the options to actually mark read. used in
        // situations where marking all read is almost certainly not what the user wants to do
        var optionalOverrideMessage: String? = null
        if (olderThan != null || newerThan != null) {
            // if this is a range mark, check that option
            if (PrefsUtils.isConfirmMarkRangeRead(activity)) doImmediate = false
        } else {
            // if this is an all mark, check that option
            val confirmation = PrefsUtils.getMarkAllReadConfirmation(activity)
            if (confirmation.feedSetRequiresConfirmation(fs)) doImmediate = false
        }
        // marks hit all stories, even when filtering via search, so warn
        if (fs.searchQuery != null) {
            doImmediate = false
            optionalOverrideMessage = activity.resources.getString(R.string.search_mark_read_warning)
        }
        if (doImmediate) {
            doAction(ra, activity)
            if (finishAfter) {
                activity.finish()
            }
        } else {
            val title: String? = when {
                fs.isAllNormal -> {
                    activity.resources.getString(R.string.all_stories)
                }
                fs.isFolder -> {
                    fs.folderName
                }
                fs.isSingleSocial -> {
                    getSocialFeed(fs.singleSocialFeed.key)?.feedTitle ?: ""
                }
                else -> {
                    getFeed(fs.singleFeed)?.title ?: ""
                }
            }
            val dialog = ReadingActionConfirmationFragment.newInstance(ra, title, optionalOverrideMessage, choicesRid, finishAfter)
            dialog.show(activity.supportFragmentManager, "dialog")
        }
    }

    @JvmStatic
    fun disableNotifications(context: Context, feed: Feed) {
        updateFeedNotifications(context, feed, enable = false, focusOnly = false)
    }

    @JvmStatic
    fun enableUnreadNotifications(context: Context, feed: Feed) {
        updateFeedNotifications(context, feed, enable = true, focusOnly = false)
    }

    @JvmStatic
    fun enableFocusNotifications(context: Context, feed: Feed) {
        updateFeedNotifications(context, feed, enable = true, focusOnly = true)
    }

    private fun updateFeedNotifications(context: Context, feed: Feed, enable: Boolean, focusOnly: Boolean) {
        NBScope.executeAsyncTask(
                doInBackground = {
                    if (focusOnly) {
                        feed.setNotifyFocus()
                    } else {
                        feed.setNotifyUnread()
                    }
                    feed.enableAndroidNotifications(enable)
                    dbHelper!!.updateFeed(feed)
                    val ra = ReadingAction.setNotify(feed.feedId, feed.notificationTypes, feed.notificationFilter)
                    doAction(ra, context)
                }
        )
    }

    @JvmStatic
    fun doAction(ra: ReadingAction?, context: Context) {
        requireNotNull(ra) { "ReadingAction must not be null" }
        NBScope.executeAsyncTask(
                doInBackground = {
                    dbHelper!!.enqueueAction(ra)
                    val impact = ra.doLocal(dbHelper)
                    syncUpdateStatus(context, impact)
                    triggerSync(context)
                }
        )
    }

    @JvmStatic
    fun updateClassifier(feedId: String?, classifier: Classifier?, fs: FeedSet?, context: Context) {
        val ra = ReadingAction.updateIntel(feedId, classifier, fs)
        doAction(ra, context)
    }

    @JvmStatic
    fun sendStoryUrl(story: Story?, context: Context) {
        if (story == null) return
        val intent = Intent(Intent.ACTION_SEND)
        intent.type = "text/plain"
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.putExtra(Intent.EXTRA_SUBJECT, story.title)
        intent.putExtra(Intent.EXTRA_TEXT, story.permalink)
        context.startActivity(Intent.createChooser(intent, "Send using"))
    }

    @JvmStatic
    fun sendStoryFull(story: Story?, context: Context) {
        if (story == null) return
        var body = getStoryText(story.storyHash)
        if (TextUtils.isEmpty(body)) body = getStoryContent(story.storyHash)
        val intent = Intent(Intent.ACTION_SEND)
        intent.type = "text/plain"
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.putExtra(Intent.EXTRA_SUBJECT, story.title)
        intent.putExtra(Intent.EXTRA_TEXT, String.format(context.resources.getString(R.string.send_full), story.title, story.permalink, UIUtils.fromHtml(body)))
        context.startActivity(Intent.createChooser(intent, "Send using"))
    }

    @JvmStatic
    fun shareStory(story: Story, comment: String?, sourceUserIdString: String?, context: Context) {
        var sourceUserId = sourceUserIdString
        if (story.sourceUserId != null) {
            sourceUserId = story.sourceUserId
        }
        val ra = ReadingAction.shareStory(story.storyHash, story.id, story.feedId, sourceUserId, comment)
        dbHelper!!.enqueueAction(ra)
        ra.doLocal(dbHelper)
        syncUpdateStatus(context, UPDATE_SOCIAL or UPDATE_STORY)
        triggerSync(context)
    }

    @JvmStatic
    fun renameFeed(context: Context, feedId: String?, newFeedName: String?) {
        val ra = ReadingAction.renameFeed(feedId, newFeedName)
        dbHelper!!.enqueueAction(ra)
        val impact = ra.doLocal(dbHelper)
        syncUpdateStatus(context, impact)
        triggerSync(context)
    }

    @JvmStatic
    fun unshareStory(story: Story, context: Context) {
        val ra = ReadingAction.unshareStory(story.storyHash, story.id, story.feedId)
        dbHelper!!.enqueueAction(ra)
        ra.doLocal(dbHelper)
        syncUpdateStatus(context, UPDATE_SOCIAL or UPDATE_STORY)
        triggerSync(context)
    }

    fun likeComment(story: Story, commentUserId: String?, context: Context) {
        val ra = ReadingAction.likeComment(story.id, commentUserId, story.feedId)
        dbHelper!!.enqueueAction(ra)
        ra.doLocal(dbHelper)
        syncUpdateStatus(context, UPDATE_SOCIAL)
        triggerSync(context)
    }

    fun unlikeComment(story: Story, commentUserId: String?, context: Context) {
        val ra = ReadingAction.unlikeComment(story.id, commentUserId, story.feedId)
        dbHelper!!.enqueueAction(ra)
        ra.doLocal(dbHelper)
        syncUpdateStatus(context, UPDATE_SOCIAL)
        triggerSync(context)
    }

    @JvmStatic
    fun replyToComment(storyId: String?, feedId: String?, commentUserId: String?, replyText: String?, context: Context) {
        val ra = ReadingAction.replyToComment(storyId, feedId, commentUserId, replyText)
        dbHelper!!.enqueueAction(ra)
        ra.doLocal(dbHelper)
        syncUpdateStatus(context, UPDATE_SOCIAL)
        triggerSync(context)
    }

    @JvmStatic
    fun updateReply(context: Context, story: Story, commentUserId: String?, replyId: String?, replyText: String?) {
        val ra = ReadingAction.updateReply(story.id, story.feedId, commentUserId, replyId, replyText)
        dbHelper!!.enqueueAction(ra)
        ra.doLocal(dbHelper)
        syncUpdateStatus(context, UPDATE_SOCIAL)
        triggerSync(context)
    }

    @JvmStatic
    fun deleteReply(context: Context, story: Story, commentUserId: String?, replyId: String?) {
        val ra = ReadingAction.deleteReply(story.id, story.feedId, commentUserId, replyId)
        dbHelper!!.enqueueAction(ra)
        ra.doLocal(dbHelper)
        syncUpdateStatus(context, UPDATE_SOCIAL)
        triggerSync(context)
    }

    @JvmStatic
    fun moveFeedToFolders(context: Context, feedId: String?, toFolders: Set<String?>, inFolders: Set<String?>?) {
        if (toFolders.isEmpty()) return
        NBScope.executeAsyncTask(
                doInBackground = {
                    val apiManager = APIManager(context)
                    apiManager.moveFeedToFolders(feedId, toFolders, inFolders)
                },
                onPostExecute = {
                    NBSyncService.forceFeedsFolders()
                    triggerSync(context)
                }
        )
    }

    @JvmStatic
    fun muteFeeds(context: Context, feedIds: Set<String>) {
        updateFeedActiveState(context, feedIds, false)
    }

    @JvmStatic
    fun unmuteFeeds(context: Context, feedIds: Set<String>) {
        updateFeedActiveState(context, feedIds, true)
    }

    private fun updateFeedActiveState(context: Context, feedIds: Set<String>, active: Boolean) {
        NBScope.executeAsyncTask(
                doInBackground = {
                    val activeFeeds = dbHelper!!.allActiveFeeds
                    for (feedId in feedIds) {
                        if (active) {
                            activeFeeds.add(feedId)
                        } else {
                            activeFeeds.remove(feedId)
                        }
                    }

                    val ra: ReadingAction = if (active) {
                        ReadingAction.unmuteFeeds(activeFeeds, feedIds)
                    } else {
                        ReadingAction.muteFeeds(activeFeeds, feedIds)
                    }

                    dbHelper!!.enqueueAction(ra)
                    ra.doLocal(dbHelper)

                    syncUpdateStatus(context, UPDATE_METADATA)
                    triggerSync(context)
                }
        )
    }

    @JvmStatic
    fun instaFetchFeed(context: Context, feedId: String?) {
        val ra = ReadingAction.instaFetch(feedId)
        dbHelper!!.enqueueAction(ra)
        ra.doLocal(dbHelper)
        syncUpdateStatus(context, UPDATE_METADATA)
        triggerSync(context)
    }

    @JvmStatic
    fun feedSetFromFolderName(folderName: String): FeedSet =
            FeedSet.folder(folderName, getFeedIdsRecursive(folderName))

    private fun getFeedIdsRecursive(folderName: String): Set<String> {
        val folder = dbHelper!!.getFolder(folderName) ?: return emptySet()
        val feedIds: MutableSet<String> = HashSet(folder.feedIds.size)
        for (id in folder.feedIds) feedIds.add(id)
        for (child in folder.children) feedIds.addAll(getFeedIdsRecursive(child))
        return feedIds
    }

    fun getStoryText(hash: String?): String? = dbHelper!!.getStoryText(hash)

    fun getStoryContent(hash: String?): String? = dbHelper!!.getStoryContent(hash)

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
     * Because story objects have to join on the feeds table to get feed metadata, there are times
     * where standalone stories are missing this info and it must be re-fetched.  This is costly
     * and should be avoided where possible.
     */
    @JvmStatic
    fun getFeedTitle(feedId: String?): String? = getFeed(feedId)?.title

    @JvmStatic
    fun getFeed(feedId: String?): Feed? = dbHelper!!.getFeed(feedId)

    fun getSocialFeed(feedId: String?): SocialFeed? = dbHelper!!.getSocialFeed(feedId)

    @JvmStatic
    fun getStarredFeedByTag(feedId: String?): StarredCount? = dbHelper!!.getStarredFeedByTag(feedId)

    @JvmStatic
    fun openStatistics(context: Context?, feedId: String) {
        val url = APIConstants.buildUrl(APIConstants.PATH_FEED_STATISTICS + feedId)
        UIUtils.handleUri(context, Uri.parse(url))
    }

    @JvmStatic
    fun syncUpdateStatus(context: Context, updateType: Int) {
        if (NbApplication.isAppForeground) {
            Intent(NBSyncReceiver.NB_SYNC_ACTION).apply {
                putExtra(NBSyncReceiver.NB_SYNC_UPDATE_TYPE, updateType)
            }.also {
                context.sendBroadcast(it)
            }
        }
    }
}