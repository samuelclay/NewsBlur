package com.newsblur.util

import android.content.Context
import android.content.Intent
import com.google.gson.Gson
import com.newsblur.activity.AllStoriesItemsList
import com.newsblur.activity.FeedItemsList
import com.newsblur.activity.FolderItemsList
import com.newsblur.activity.ItemsList
import com.newsblur.activity.SocialFeedItemsList
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.Feed
import com.newsblur.domain.SocialFeed

/**
 * Remembers the last story list opened so a tablet can reopen it at launch, with the feed list
 * slid over it (FeedListDrawer.kt). Phones never read it. Anything that can't be rebuilt, such
 * as a feed that has since been removed, falls back to All Site Stories.
 *
 * The feed set and social feed are kept as JSON rather than Java serialization, so a field added
 * to either later still restores instead of silently falling back.
 */
object LastStoryList {
    private const val KEY_CLASS = "last_story_list_class"
    private const val KEY_FEED_SET = "last_story_list_feed_set"
    private const val KEY_FOLDER_NAME = "last_story_list_folder_name"
    private const val KEY_SOCIAL_FEED = "last_story_list_social_feed"

    private val gson = Gson()

    /** What LastStoryList.kt keeps in preferences, as plain strings. */
    internal data class Saved(
        val storyListClass: String?,
        val feedSet: String?,
        val folderName: String?,
        val socialFeed: String?,
    )

    /** The story list launch reopens, with the extras that story list needs. */
    internal data class Destination(
        val storyListClass: Class<*>,
        val feedSet: FeedSet,
        val folderName: String? = null,
        val feed: Feed? = null,
        val socialFeed: SocialFeed? = null,
    )

    /**
     * ItemsList.java calls this whenever it shows a story list, including advancing to the next
     * feed or folder, with that session's folder name (the launch intent's goes stale).
     */
    @JvmStatic
    fun remember(
        context: Context,
        storyList: ItemsList,
        feedSet: FeedSet,
        folderName: String?,
    ) {
        val saved =
            save(
                storyListClass = storyList.javaClass,
                feedSet = feedSet,
                folderName = folderName,
                socialFeed = storyList.intent.getSerializableExtra(SocialFeedItemsList.EXTRA_SOCIAL_FEED) as? SocialFeed,
                isTryFeed = storyList.intent.getBooleanExtra(FeedItemsList.EXTRA_IS_TRY_FEED, false),
            ) ?: return
        preferences(context)
            .edit()
            .putString(KEY_CLASS, saved.storyListClass)
            .putString(KEY_FEED_SET, saved.feedSet)
            .putString(KEY_FOLDER_NAME, saved.folderName)
            .putString(KEY_SOCIAL_FEED, saved.socialFeed)
            .apply()
    }

    /**
     * The intent that reopens the last story list, or All Site Stories when there isn't one to
     * rebuild. Main.java calls this while it starts, so the database reads are kept to one feed
     * row or one folder's feed IDs.
     */
    @JvmStatic
    fun intent(
        context: Context,
        dbHelper: BlurDatabaseHelper,
    ): Intent {
        val preferences = preferences(context)
        val saved =
            Saved(
                storyListClass = preferences.getString(KEY_CLASS, null),
                feedSet = preferences.getString(KEY_FEED_SET, null),
                folderName = preferences.getString(KEY_FOLDER_NAME, null),
                socialFeed = preferences.getString(KEY_SOCIAL_FEED, null),
            )
        val destination =
            runCatching {
                restore(
                    saved,
                    findFolder = { folderName -> dbHelper.feedSetFromFolderName(folderName) },
                    findFeed = { feedId -> dbHelper.getFeed(feedId) },
                )
            }.getOrNull()
        return destination?.let { toIntent(context, it) } ?: toIntent(context, allSiteStories())
    }

    // A feed preview (Discover, Related Sites) isn't a subscription to come back to.
    internal fun save(
        storyListClass: Class<*>,
        feedSet: FeedSet,
        folderName: String?,
        socialFeed: SocialFeed?,
        isTryFeed: Boolean,
    ): Saved? {
        if (isTryFeed) return null
        // A social feed list advanced to another feed set no longer matches its launch extra.
        val matchingSocialFeed = socialFeed?.takeIf { it.userId == feedSet.singleSocialFeed?.key }
        return Saved(
            storyListClass = storyListClass.name,
            feedSet = runCatching { gson.toJson(feedSet) }.getOrNull() ?: return null,
            folderName = folderName,
            socialFeed = matchingSocialFeed?.let { runCatching { gson.toJson(it) }.getOrNull() },
        )
    }

    internal fun restore(
        saved: Saved,
        findFolder: (String) -> FeedSet?,
        findFeed: (String) -> Feed?,
    ): Destination? {
        val storyListClass = runCatching { Class.forName(saved.storyListClass ?: return null) }.getOrNull() ?: return null
        if (!ItemsList::class.java.isAssignableFrom(storyListClass)) return null
        val feedSet = runCatching { gson.fromJson(saved.feedSet ?: return null, FeedSet::class.java) }.getOrNull() ?: return null
        // Gson skips keys it doesn't know instead of failing, so JSON written under other field
        // names comes back as a set no story list can load.
        if (!feedSet.loadsStories()) return null
        // A search is a moment, not a place to reopen.
        feedSet.searchQuery = null
        return when (storyListClass) {
            FolderItemsList::class.java -> {
                // The saved feed IDs go stale when the folder changes on another device, so the
                // folder is rebuilt by name. A folder that has since been deleted comes back empty.
                val folderName = saved.folderName ?: return null
                val folderSet = findFolder(folderName)?.takeIf { !it.allFeeds.isNullOrEmpty() } ?: return null
                // Only the membership is refreshed. How the list was being read comes along, such
                // as the Saved view FolderListAdapter.java turns on with isFilterSaved.
                folderSet.isFilterSaved = feedSet.isFilterSaved
                folderSet.isMuted = feedSet.isMuted
                folderSet.stateFilterOverride = feedSet.stateFilterOverride
                folderSet.readFilterOverride = feedSet.readFilterOverride
                Destination(storyListClass, folderSet, folderName = folderName)
            }

            FeedItemsList::class.java -> {
                // FeedItemsList.kt can't open without its folder (a saved search on a feed has none).
                val folderName = saved.folderName ?: return null
                val feed = findFeed(feedSet.singleFeed ?: return null) ?: return null
                Destination(storyListClass, feedSet, folderName = folderName, feed = feed)
            }

            SocialFeedItemsList::class.java -> {
                val socialFeed =
                    runCatching { gson.fromJson(saved.socialFeed ?: return null, SocialFeed::class.java) }.getOrNull()
                        ?: return null
                Destination(storyListClass, feedSet, socialFeed = socialFeed)
            }

            else -> {
                Destination(storyListClass, feedSet)
            }
        }
    }

    internal fun allSiteStories(): Destination = Destination(AllStoriesItemsList::class.java, FeedSet.allFeeds())

    /** The same types BlurDatabaseHelper.getLocalStorySelectionAndArgs knows how to load. */
    private fun FeedSet.loadsStories(): Boolean =
        isDailyBriefing ||
            isTrending ||
            singleFeed != null ||
            multipleFeeds != null ||
            singleSocialFeed != null ||
            isAllNormal ||
            isAllSocial ||
            isAllRead ||
            isAllSaved ||
            isInfrequent ||
            singleSavedTag != null ||
            isGlobalShared

    private fun toIntent(
        context: Context,
        destination: Destination,
    ): Intent {
        val intent =
            Intent(context, destination.storyListClass)
                .putExtra(ItemsList.EXTRA_FEED_SET, destination.feedSet)
        when (destination.storyListClass) {
            FolderItemsList::class.java -> {
                intent.putExtra(FolderItemsList.EXTRA_FOLDER_NAME, destination.folderName)
            }

            FeedItemsList::class.java -> {
                intent
                    .putExtra(FeedItemsList.EXTRA_FEED, destination.feed)
                    .putExtra(FeedItemsList.EXTRA_FOLDER_NAME, destination.folderName)
            }

            SocialFeedItemsList::class.java -> {
                intent.putExtra(SocialFeedItemsList.EXTRA_SOCIAL_FEED, destination.socialFeed)
            }
        }
        return intent
    }

    private fun preferences(context: Context) = context.getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE)
}
