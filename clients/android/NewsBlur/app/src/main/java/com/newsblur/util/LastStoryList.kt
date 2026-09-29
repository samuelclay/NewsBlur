package com.newsblur.util

import android.content.Context
import android.content.Intent
import android.util.Base64
import com.newsblur.activity.AllStoriesItemsList
import com.newsblur.activity.FeedItemsList
import com.newsblur.activity.FolderItemsList
import com.newsblur.activity.ItemsList
import com.newsblur.activity.SocialFeedItemsList
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.domain.SocialFeed
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.ObjectInputStream
import java.io.ObjectOutputStream
import java.io.Serializable

/**
 * Remembers the last story list opened so a tablet can reopen it at launch, with the feed list
 * slid over it (FeedListDrawer.kt). Phones never read it. Anything that can't be rebuilt, such
 * as a feed that has since been removed, falls back to All Site Stories.
 */
object LastStoryList {
    private const val KEY_CLASS = "last_story_list_class"
    private const val KEY_FEED_SET = "last_story_list_feed_set"
    private const val KEY_FOLDER_NAME = "last_story_list_folder_name"
    private const val KEY_SOCIAL_FEED = "last_story_list_social_feed"

    /** ItemsList.java calls this whenever it shows a story list, including advancing to the next feed. */
    @JvmStatic
    fun remember(
        context: Context,
        storyList: ItemsList,
        feedSet: FeedSet,
    ) {
        // A feed preview (Discover, Related Sites) isn't a subscription to come back to.
        if (storyList.intent.getBooleanExtra(FeedItemsList.EXTRA_IS_TRY_FEED, false)) return
        val encodedFeedSet = encode(feedSet) ?: return
        val folderName =
            storyList.intent.getStringExtra(FolderItemsList.EXTRA_FOLDER_NAME)
                ?: storyList.intent.getStringExtra(FeedItemsList.EXTRA_FOLDER_NAME)
        val socialFeed =
            (storyList.intent.getSerializableExtra(SocialFeedItemsList.EXTRA_SOCIAL_FEED) as? SocialFeed)?.let(::encode)
        preferences(context)
            .edit()
            .putString(KEY_CLASS, storyList.javaClass.name)
            .putString(KEY_FEED_SET, encodedFeedSet)
            .putString(KEY_FOLDER_NAME, folderName)
            .putString(KEY_SOCIAL_FEED, socialFeed)
            .apply()
    }

    /** The intent that reopens the last story list, or All Site Stories when there isn't one to rebuild. */
    @JvmStatic
    fun intent(
        context: Context,
        dbHelper: BlurDatabaseHelper,
    ): Intent = runCatching { rebuild(context, dbHelper) }.getOrNull() ?: allSiteStories(context)

    private fun rebuild(
        context: Context,
        dbHelper: BlurDatabaseHelper,
    ): Intent? {
        val preferences = preferences(context)
        val storyListClass = Class.forName(preferences.getString(KEY_CLASS, null) ?: return null)
        if (!ItemsList::class.java.isAssignableFrom(storyListClass)) return null
        val feedSet = decode<FeedSet>(preferences.getString(KEY_FEED_SET, null)) ?: return null
        // A search is a moment, not a place to reopen.
        feedSet.setSearchQuery(null)
        val folderName = preferences.getString(KEY_FOLDER_NAME, null)
        val intent =
            Intent(context, storyListClass)
                .putExtra(ItemsList.EXTRA_FEED_SET, feedSet)
        when (storyListClass) {
            FolderItemsList::class.java -> intent.putExtra(FolderItemsList.EXTRA_FOLDER_NAME, folderName ?: return null)
            FeedItemsList::class.java -> {
                val feed = dbHelper.getFeed(feedSet.singleFeed ?: return null) ?: return null
                intent.putExtra(FeedItemsList.EXTRA_FEED, feed).putExtra(FeedItemsList.EXTRA_FOLDER_NAME, folderName)
            }
            SocialFeedItemsList::class.java -> {
                val socialFeed = decode<SocialFeed>(preferences.getString(KEY_SOCIAL_FEED, null)) ?: return null
                intent.putExtra(SocialFeedItemsList.EXTRA_SOCIAL_FEED, socialFeed)
            }
        }
        return intent
    }

    private fun allSiteStories(context: Context): Intent =
        Intent(context, AllStoriesItemsList::class.java).putExtra(ItemsList.EXTRA_FEED_SET, FeedSet.allFeeds())

    private fun preferences(context: Context) = context.getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE)

    private fun encode(value: Serializable): String? =
        runCatching {
            val bytes = ByteArrayOutputStream()
            ObjectOutputStream(bytes).use { it.writeObject(value) }
            Base64.encodeToString(bytes.toByteArray(), Base64.NO_WRAP)
        }.getOrNull()

    private inline fun <reified T> decode(encoded: String?): T? =
        encoded?.let {
            runCatching {
                ObjectInputStream(ByteArrayInputStream(Base64.decode(it, Base64.NO_WRAP))).use { input -> input.readObject() as? T }
            }.getOrNull()
        }
}
