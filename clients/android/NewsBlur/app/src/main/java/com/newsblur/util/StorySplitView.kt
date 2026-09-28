package com.newsblur.util

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.window.embedding.ActivityEmbeddingController
import androidx.window.embedding.ActivityFilter
import androidx.window.embedding.ActivityRule
import androidx.window.embedding.EmbeddingAspectRatio
import androidx.window.embedding.EmbeddingRule
import androidx.window.embedding.RuleController
import androidx.window.embedding.SplitAttributes
import androidx.window.embedding.SplitController
import androidx.window.embedding.SplitPairFilter
import androidx.window.embedding.SplitPairRule
import androidx.window.embedding.SplitPlaceholderRule
import androidx.window.embedding.SplitRule
import com.newsblur.activity.AllSharedStoriesItemsList
import com.newsblur.activity.AllSharedStoriesReading
import com.newsblur.activity.AllStoriesItemsList
import com.newsblur.activity.AllStoriesReading
import com.newsblur.activity.ContactActivity
import com.newsblur.activity.DailyBriefingActivity
import com.newsblur.activity.DailyBriefingReading
import com.newsblur.activity.DiscoverFeedsActivity
import com.newsblur.activity.DiscoverSitesActivity
import com.newsblur.activity.FeedItemsList
import com.newsblur.activity.FeedReading
import com.newsblur.activity.FeedSearchActivity
import com.newsblur.activity.FolderItemsList
import com.newsblur.activity.FolderReading
import com.newsblur.activity.GlobalSharedStoriesItemsList
import com.newsblur.activity.GlobalSharedStoriesReading
import com.newsblur.activity.GoodReadsItemsList
import com.newsblur.activity.GoodReadsReading
import com.newsblur.activity.ImportExportActivity
import com.newsblur.activity.InfrequentItemsList
import com.newsblur.activity.InfrequentReading
import com.newsblur.activity.LongReadsItemsList
import com.newsblur.activity.LongReadsReading
import com.newsblur.activity.Main
import com.newsblur.activity.MuteConfig
import com.newsblur.activity.NotificationsActivity
import com.newsblur.activity.Profile
import com.newsblur.activity.ReadStoriesItemsList
import com.newsblur.activity.ReadStoriesReading
import com.newsblur.activity.ReadingPlaceholder
import com.newsblur.activity.SavedStoriesItemsList
import com.newsblur.activity.SavedStoriesReading
import com.newsblur.activity.Settings
import com.newsblur.activity.SocialFeedItemsList
import com.newsblur.activity.SocialFeedReading
import com.newsblur.activity.SubscriptionActivity
import com.newsblur.activity.WidelyReadStoriesItemsList
import com.newsblur.activity.WidelyReadStoriesReading

/**
 * Puts the story list and the reader side by side on tablets and unfolded foldables.
 *
 * Every story list (ItemsList.java subclasses) and reader (Reading.kt subclasses) is still its
 * own activity. Jetpack Activity Embedding places a reader launched from a story list into a
 * pane to the right of that list, and fills the pane with ReadingPlaceholder.kt until a story
 * is picked. Phones and narrow windows never match these rules, so they keep the existing
 * full screen flow and its custom transitions.
 */
object StorySplitView {
    // Width of the story list pane. The reader gets the rest.
    const val STORY_LIST_SPLIT_RATIO = 0.4f

    // 600dp is where Material's medium window size class starts: unfolded foldables and
    // tablets in either orientation, but never a phone held sideways.
    const val MIN_SPLIT_WIDTH_DP = 600

    private val STORY_LIST_ACTIVITIES =
        listOf(
            AllSharedStoriesItemsList::class.java,
            AllStoriesItemsList::class.java,
            FeedItemsList::class.java,
            FolderItemsList::class.java,
            GlobalSharedStoriesItemsList::class.java,
            GoodReadsItemsList::class.java,
            InfrequentItemsList::class.java,
            LongReadsItemsList::class.java,
            ReadStoriesItemsList::class.java,
            SavedStoriesItemsList::class.java,
            SocialFeedItemsList::class.java,
            WidelyReadStoriesItemsList::class.java,
        )

    private val READING_ACTIVITIES =
        listOf(
            AllSharedStoriesReading::class.java,
            AllStoriesReading::class.java,
            DailyBriefingReading::class.java,
            FeedReading::class.java,
            FolderReading::class.java,
            GlobalSharedStoriesReading::class.java,
            GoodReadsReading::class.java,
            InfrequentReading::class.java,
            LongReadsReading::class.java,
            ReadStoriesReading::class.java,
            SavedStoriesReading::class.java,
            SocialFeedReading::class.java,
            WidelyReadStoriesReading::class.java,
        )

    // Screens opened from inside a split that need the whole window rather than one pane.
    private val FULL_WINDOW_ACTIVITIES =
        listOf(
            ContactActivity::class.java,
            DailyBriefingActivity::class.java,
            DiscoverFeedsActivity::class.java,
            DiscoverSitesActivity::class.java,
            FeedSearchActivity::class.java,
            ImportExportActivity::class.java,
            Main::class.java,
            MuteConfig::class.java,
            NotificationsActivity::class.java,
            Profile::class.java,
            Settings::class.java,
            SubscriptionActivity::class.java,
        )

    /**
     * Registers the split rules once per process from NbApplication.kt. Devices without
     * Activity Embedding support (most phones, Android before 12L) skip this entirely.
     */
    @JvmStatic
    fun install(context: Context) {
        if (SplitController.getInstance(context).splitSupportStatus != SplitController.SplitSupportStatus.SPLIT_AVAILABLE) {
            return
        }
        RuleController.getInstance(context).setRules(buildRules(context))
    }

    /**
     * True when this activity is currently showing in one pane of a split. Reading.kt and
     * ItemsList.java use this to turn off the full screen slide and swipe back animations,
     * which assume the list sits underneath the reader.
     */
    @JvmStatic
    fun isInSplit(activity: Activity): Boolean = ActivityEmbeddingController.getInstance(activity).isActivityEmbedded(activity)

    internal fun buildRules(context: Context): Set<EmbeddingRule> {
        val splitAttributes =
            SplitAttributes
                .Builder()
                .setSplitType(SplitAttributes.SplitType.ratio(STORY_LIST_SPLIT_RATIO))
                .setLayoutDirection(SplitAttributes.LayoutDirection.LOCALE)
                .build()

        val storyListToReaderFilters =
            STORY_LIST_ACTIVITIES
                .flatMap { storyList ->
                    READING_ACTIVITIES.map { reader ->
                        SplitPairFilter(ComponentName(context, storyList), ComponentName(context, reader), null)
                    }
                }.toSet()

        val storyListToReader =
            SplitPairRule
                .Builder(storyListToReaderFilters)
                .setTag(TAG_STORY_LIST_READER)
                .setDefaultSplitAttributes(splitAttributes)
                .setMinWidthDp(MIN_SPLIT_WIDTH_DP)
                .setMinSmallestWidthDp(MIN_SPLIT_WIDTH_DP)
                .setMaxAspectRatioInPortrait(EmbeddingAspectRatio.ALWAYS_ALLOW)
                .setMaxAspectRatioInLandscape(EmbeddingAspectRatio.ALWAYS_ALLOW)
                // Leaving a story list closes its reader, but closing the reader keeps the list.
                .setFinishPrimaryWithSecondary(SplitRule.FinishBehavior.NEVER)
                .setFinishSecondaryWithPrimary(SplitRule.FinishBehavior.ALWAYS)
                // Tapping another story replaces the reader pane instead of stacking readers.
                .setClearTop(true)
                .build()

        val storyListFilters =
            STORY_LIST_ACTIVITIES.map { storyList -> ActivityFilter(ComponentName(context, storyList), null) }.toSet()

        val emptyReaderPane =
            SplitPlaceholderRule
                .Builder(storyListFilters, Intent(context, ReadingPlaceholder::class.java))
                .setTag(TAG_EMPTY_READER)
                .setDefaultSplitAttributes(splitAttributes)
                .setMinWidthDp(MIN_SPLIT_WIDTH_DP)
                .setMinSmallestWidthDp(MIN_SPLIT_WIDTH_DP)
                .setMaxAspectRatioInPortrait(EmbeddingAspectRatio.ALWAYS_ALLOW)
                .setMaxAspectRatioInLandscape(EmbeddingAspectRatio.ALWAYS_ALLOW)
                .setFinishPrimaryWithPlaceholder(SplitRule.FinishBehavior.ALWAYS)
                .setSticky(false)
                .build()

        val fullWindowFilters =
            FULL_WINDOW_ACTIVITIES.map { activity -> ActivityFilter(ComponentName(context, activity), null) }.toSet()

        val fullWindow =
            ActivityRule
                .Builder(fullWindowFilters)
                .setTag(TAG_FULL_WINDOW)
                .setAlwaysExpand(true)
                .build()

        return setOf(storyListToReader, emptyReaderPane, fullWindow)
    }

    private const val TAG_STORY_LIST_READER = "story_list_reader"
    private const val TAG_EMPTY_READER = "empty_reader"
    private const val TAG_FULL_WINDOW = "full_window"
}
