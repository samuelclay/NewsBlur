package com.newsblur.util

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
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
import com.newsblur.activity.FeedListDrawer
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
import com.newsblur.image.StoryImageViewerHost
import kotlinx.coroutines.launch
import java.util.WeakHashMap

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

    internal val STORY_LIST_ACTIVITIES =
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

    internal val READING_ACTIVITIES =
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
    // Main.java is deliberately absent: an always expanded Main would host the story list in
    // its own container, so closing the list would leave Main beside an orphaned reader.
    private val FULL_WINDOW_ACTIVITIES =
        listOf(
            ContactActivity::class.java,
            DailyBriefingActivity::class.java,
            DiscoverFeedsActivity::class.java,
            DiscoverSitesActivity::class.java,
            FeedSearchActivity::class.java,
            ImportExportActivity::class.java,
            MuteConfig::class.java,
            NotificationsActivity::class.java,
            Profile::class.java,
            Settings::class.java,
            SubscriptionActivity::class.java,
            // A photo opened from the reader pane covers the story list too.
            StoryImageViewerHost::class.java,
            // The feed list slides over both panes.
            FeedListDrawer::class.java,
        )

    private var rulesInstalled = false

    /**
     * Registers the split rules the first time a window is wide enough to split: from
     * NbApplication.kt at startup, and from NbActivity.kt for every activity after that, so a
     * foldable that starts out folded picks them up once it opens (opening recreates its
     * activities). Phones, flip phones included, never reach split width and never get the rules.
     * That matters because with rules installed, Activity Embedding moves matching activities
     * into embedded containers even while too narrow to split, which also changes their
     * transitions. Rules apply to activities launched after they are set.
     */
    @JvmStatic
    fun installIfWideEnough(context: Context) {
        if (rulesInstalled) return
        if (!shouldInstallRules(context.resources.configuration.smallestScreenWidthDp)) return
        if (SplitController.getInstance(context).splitSupportStatus != SplitController.SplitSupportStatus.SPLIT_AVAILABLE) {
            return
        }
        RuleController.getInstance(context).setRules(buildRules(context))
        rulesInstalled = true
    }

    internal fun shouldInstallRules(smallestScreenWidthDp: Int): Boolean = smallestScreenWidthDp >= MIN_SPLIT_WIDTH_DP

    // Split membership for each story list and reader, as last reported by splitInfoList (trackSplit).
    private val reportedSplitMembership = WeakHashMap<Activity, Boolean>()

    /**
     * True when this activity is currently showing in one pane of a split. Reading.kt and
     * ItemsList.java use this to turn off the full screen slide and swipe back animations,
     * which assume the list sits underneath the reader.
     */
    @JvmStatic
    fun isInSplit(activity: Activity): Boolean {
        // Without rules (every phone) nothing is ever embedded, so skip the embedding controller.
        if (!rulesInstalled) return false
        return resolveInSplit(reportedSplitMembership[activity]) {
            isSplitPane(activity.isInMultiWindowMode) {
                ActivityEmbeddingController.getInstance(activity).isActivityEmbedded(activity)
            }
        }
    }

    // splitInfoList is the only reliable answer: in system split screen beside another app, or a
    // desktop window, every activity is in multi-window mode, including story lists stacked in
    // expanded containers with no NewsBlur split showing. The windowing check only covers the
    // moment before splitInfoList first reports, such as Reading.kt's onCreate.
    internal fun resolveInSplit(
        reportedInSplit: Boolean?,
        beforeFirstReport: () -> Boolean,
    ): Boolean = reportedInSplit ?: beforeFirstReport()

    // Jetpack keeps a SplitInfo with its containers stacked (expanded) when the window gets too
    // narrow, such as a foldable closing, so only a split whose panes sit side by side counts.
    internal fun isSideBySide(splitTypes: List<SplitAttributes.SplitType>): Boolean =
        splitTypes.any { splitType -> splitType != SplitAttributes.SplitType.SPLIT_TYPE_EXPAND }

    // Activities in an always expanded container (FULL_WINDOW_ACTIVITIES, and anything they
    // open, like Daily Briefing's reader) are embedded too, but fill the window. Only split
    // panes are in multi-window mode, which is checked first so full screen activities never
    // reach the embedding controller.
    internal fun isSplitPane(
        isInMultiWindowMode: Boolean,
        isEmbedded: () -> Boolean,
    ): Boolean = isInMultiWindowMode && isEmbedded()

    /**
     * Follows a story list or reader in and out of splits, recording its membership for isInSplit.
     *
     * ItemsList.java and Reading.kt are also declared with Theme.Translucent in
     * AndroidManifest.xml so their phone transitions can show the screen underneath. In a split
     * that translucency lets Main.java count as visible behind the panes, so Android resumes it
     * (on rotation, say), and Main.java's onResume resets the reading session the story list and
     * reader share, which empties the list. So the window turns opaque once it lands in a split
     * and stays opaque for the rest of its life. Turning translucent again when a foldable closes
     * would reopen the same window while Main relaunches, and the only cost of staying opaque is
     * that this one activity's phone swipe back shows no screen behind it until it is reopened.
     */
    @JvmStatic
    fun trackSplit(activity: ComponentActivity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        // Without rules (every phone) nothing can land in a split, so skip the subscription.
        if (!rulesInstalled) return
        var isOpaque = false
        activity.lifecycleScope.launch {
            activity.repeatOnLifecycle(Lifecycle.State.STARTED) {
                SplitController.getInstance(activity).splitInfoList(activity).collect { splits ->
                    val inSplit = isSideBySide(splits.map { split -> split.splitAttributes.splitType })
                    reportedSplitMembership[activity] = inSplit
                    if (inSplit && !isOpaque) {
                        isOpaque = true
                        activity.setTranslucent(false)
                    }
                }
            }
        }
    }

    /**
     * Starts a story list. On a tablet, a story list opened from inside the split or an always
     * expanded screen (a reader's Go to feed, the next folder, Discover, the feed list slide-over)
     * would land wherever Activity Embedding's defaults put it: beside the old list in the reader
     * pane, or in an expanded container that never splits. So those launches start the story list
     * as the root of a fresh task instead, which gives it a new split with the placeholder pane;
     * Back from it slides the feed list over (FeedListDrawer.kt). Phones never embed anything and
     * start the list directly.
     */
    @JvmStatic
    fun startStoryList(
        context: Context,
        storyList: Intent,
    ) {
        val activity = if (rulesInstalled) findActivity(context) else null
        val restartTask =
            activity != null &&
                shouldRestartTaskForStoryList(rulesInstalled) {
                    ActivityEmbeddingController.getInstance(activity).isActivityEmbedded(activity)
                }
        if (restartTask) {
            storyList.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        context.startActivity(storyList)
    }

    // Without rules (every phone) nothing is ever embedded, so the embedding controller is never asked.
    internal fun shouldRestartTaskForStoryList(
        rulesInstalled: Boolean,
        isEmbedded: () -> Boolean,
    ): Boolean = rulesInstalled && isEmbedded()

    /**
     * True when this window uses tablet navigation: story list and reader side by side, with the
     * feed list sliding over them (FeedListDrawer.kt) instead of filling the screen. Matches the
     * split rules' own width checks, so a narrow window (system split screen, a folded foldable)
     * keeps the phone flow.
     */
    @JvmStatic
    fun usesTabletNavigation(context: Context): Boolean {
        if (!rulesInstalled) return false
        val configuration = context.resources.configuration
        return configuration.screenWidthDp >= MIN_SPLIT_WIDTH_DP && configuration.smallestScreenWidthDp >= MIN_SPLIT_WIDTH_DP
    }

    /**
     * True when going back from this story list slides the feed list over it (FeedListDrawer.kt)
     * instead of closing it. With tablet navigation, Main.java and FeedListDrawer.kt start every
     * story list as the root of its task, so there is no feed list underneath to return to. The
     * list's own width can't decide this: in a pane it is narrower than a phone, and its first
     * resume comes before the split is reported. Phones never install the rules and keep going
     * back to Main.java.
     */
    @JvmStatic
    fun slidesOverFeedDrawer(storyList: Activity): Boolean = shouldSlideOverFeedDrawer(rulesInstalled, storyList.isTaskRoot)

    internal fun shouldSlideOverFeedDrawer(
        rulesInstalled: Boolean,
        isTaskRoot: Boolean,
    ): Boolean = rulesInstalled && isTaskRoot

    /** True when [intent] opens one of the story lists in the split rules. */
    @JvmStatic
    fun isStoryList(intent: Intent): Boolean {
        val className = intent.component?.className ?: return false
        return STORY_LIST_ACTIVITIES.any { storyList -> storyList.name == className }
    }

    // Unwraps Hilt's fragment context wrappers to the hosting activity.
    private fun findActivity(context: Context): Activity? {
        var current: Context? = context
        while (current is ContextWrapper) {
            if (current is Activity) return current
            current = current.baseContext
        }
        return null
    }

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
