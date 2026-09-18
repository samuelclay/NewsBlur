@file:OptIn(ExperimentalCoroutinesApi::class)

package com.newsblur.database

import android.graphics.Color
import android.graphics.Typeface
import android.os.Parcelable
import android.os.SystemClock
import android.text.TextUtils
import android.text.SpannedString
import android.view.ContextMenu
import android.view.ContextMenu.ContextMenuInfo
import android.view.LayoutInflater
import android.view.MenuInflater
import android.view.MenuItem
import android.view.MotionEvent
import android.view.View
import android.view.View.OnCreateContextMenuListener
import android.view.View.OnTouchListener
import android.view.ViewGroup
import android.view.ViewConfiguration
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.PopupWindow
import android.widget.RelativeLayout
import android.widget.TextView
import androidx.core.view.doOnLayout
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.BuildConfig
import com.newsblur.R
import com.newsblur.activity.FeedItemsList
import com.newsblur.activity.ItemsList
import com.newsblur.activity.NbActivity
import com.newsblur.design.StoryRowPalette
import com.newsblur.delegate.StoryMenuPopover
import com.newsblur.domain.CustomIcon
import com.newsblur.domain.Story
import com.newsblur.util.AppConstants
import com.newsblur.util.CustomIconRenderer
import com.newsblur.fragment.ReturnedStoryScrollDecider
import com.newsblur.fragment.StoryIntelTrainerFragment
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.GestureAction
import com.newsblur.util.ImageLoader
import com.newsblur.util.ImageLoader.PhotoToLoad
import com.newsblur.util.Log
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.SpacingStyle
import com.newsblur.util.StoryClusterBadgeViewBinder
import com.newsblur.util.StoryRowThumbnailVerticalMode
import com.newsblur.util.StoryContentPreviewStyle
import com.newsblur.util.StoryClusterDisplayDecision
import com.newsblur.util.StoryClusterNavigationDecision
import com.newsblur.util.StoryClusterNavigationTarget
import com.newsblur.util.StoryClusterThemeStyle
import com.newsblur.util.StoryListStyle
import com.newsblur.util.StoryOrder
import com.newsblur.util.StoryUtil.getNewestStoryTimestamp
import com.newsblur.util.StoryUtil.getOldestStoryTimestamp
import com.newsblur.util.StoryUtil.getStoryHashes
import com.newsblur.util.StoryUtils
import com.newsblur.util.ThumbnailStyle
import com.newsblur.util.UIUtils
import com.newsblur.util.storyRowLayout
import com.newsblur.view.StoryThumbnailView
import com.newsblur.viewModel.LatestStoryLoadRunner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.SupervisorJob
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Story list adapter, RecyclerView style.
 */
class StoryViewAdapter(
    private val context: NbActivity,
    fs: FeedSet,
    listStyle: StoryListStyle,
    iconLoader: ImageLoader,
    thumbnailLoader: ImageLoader,
    feedUtils: FeedUtils,
    prefsRepo: PrefsRepo,
    listener: OnStoryClickListener,
) : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
    private val footerViews = mutableListOf<View>()
    private var lastStoryOpenElapsedRealtime = 0L

    private val stories = mutableListOf<Story>()
    private val displayItems = mutableListOf<DisplayItem>()
    private val storyDisplayPositions = mutableListOf<Int>()

    private var oldScrollState: Parcelable? = null
    private var pendingScrollStoryHash: String? = null
    private var pendingHighlightStoryHash: String? = null
    private var returnPresentationReady = true
    private var returnHighlight: ReturnedStoryHighlight? = null
    private var returnObserver: ViewTreeObserver? = null
    private var returnPreDrawListener: ViewTreeObserver.OnPreDrawListener? = null
    private var returnFocusListener: ViewTreeObserver.OnWindowFocusChangeListener? = null
    private val userId: String?

    private val iconLoader: ImageLoader
    private val thumbnailLoader: ImageLoader
    private val feedUtils: FeedUtils
    private val listener: OnStoryClickListener
    private var fs: FeedSet?
    private var listStyle: StoryListStyle
    private var ignoreReadStatus = false
    private var ignoreIntel = false
    private var singleFeed = false
    private var textSize: Float
    private var thumbnailStyle: ThumbnailStyle
    private var spacingStyle: SpacingStyle
    private val storyOrder: StoryOrder
    private val prefsRepo: PrefsRepo
    private var activeFeedIds: Set<String>? = null
    private val clusterThumbnailUrls = mutableMapOf<String, String?>()
    private val titleCache = StoryTitleCache { SpannedString(UIUtils.fromHtml(it)) }
    private val useHardwareRowLayers: Boolean

    private var lastLoadId: Long = -1L
    private var committedLoadId: Long = -1L
    private var diffGeneration = 0L
    private var diffFeedSet: FeedSet? = FeedSet.fromCompactSerial(fs.toCompactSerial())
    private val adapterScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val diffDispatcher: CoroutineDispatcher = Dispatchers.Default.limitedParallelism(1)
    private var diffRunner: LatestStoryLoadRunner<StorySubmission, StoryDifference>? = null
    private var latestSubmission: StorySubmission? = null

    val isUpdatingStories: Boolean
        get() = lastLoadId != committedLoadId

    init {
        this.fs = fs
        this.listStyle = listStyle
        this.iconLoader = iconLoader
        this.thumbnailLoader = thumbnailLoader
        this.feedUtils = feedUtils
        this.listener = listener
        this.prefsRepo = prefsRepo
        useHardwareRowLayers = !BuildConfig.DEBUG || prefsRepo.getBoolean("debug_story_row_hardware_layers", true)

        if (fs.isGlobalShared) {
            ignoreReadStatus = false
            ignoreIntel = true
            singleFeed = false
        }
        if (fs.isAllSocial) {
            ignoreReadStatus = false
            ignoreIntel = false
            singleFeed = false
        }
        if (fs.isAllNormal) {
            ignoreReadStatus = false
            ignoreIntel = false
            singleFeed = false
        }
        if (fs.isInfrequent) {
            ignoreReadStatus = false
            ignoreIntel = false
            singleFeed = false
        }
        if (fs.isTrending) {
            ignoreReadStatus = false
            ignoreIntel = false
            singleFeed = false
        }
        if (fs.isSingleSocial) {
            ignoreReadStatus = false
            ignoreIntel = false
            singleFeed = false
        }
        if (fs.isFolder) {
            ignoreReadStatus = fs.isFilterSaved
            ignoreIntel = fs.isFilterSaved
            singleFeed = false
        }
        if (fs.isSingleNormal) {
            ignoreReadStatus = fs.isFilterSaved
            ignoreIntel = fs.isFilterSaved
            singleFeed = true
        }
        if (fs.isAllRead) {
            ignoreReadStatus = false
            ignoreIntel = true
            singleFeed = false
        }
        if (fs.isAllSaved) {
            ignoreReadStatus = true
            ignoreIntel = true
            singleFeed = false
        }
        if (fs.isSingleSavedTag) {
            ignoreReadStatus = true
            ignoreIntel = true
            singleFeed = false
        }

        textSize = prefsRepo.getListTextSize()
        userId = prefsRepo.getUserDetails().id
        thumbnailStyle = prefsRepo.getThumbnailStyle()
        spacingStyle = prefsRepo.getSpacingStyle()
        storyOrder = prefsRepo.getStoryOrder(fs)

        setHasStableIds(true)
    }

    fun updateFeedSet(fs: FeedSet?) {
        if (fs != diffFeedSet) {
            invalidateStoryDiffs()
            oldScrollState = null
            pendingScrollStoryHash = null
            pendingHighlightStoryHash = null
            returnHighlight?.cancel()
            returnHighlight = null
            diffFeedSet = fs?.let { FeedSet.fromCompactSerial(it.toCompactSerial()) }
        }
        this.fs = fs
    }

    private fun invalidateStoryDiffs() {
        diffGeneration++
        diffRunner?.invalidate()
        latestSubmission = null
        lastLoadId = -1L
        committedLoadId = -1L
    }

    @Synchronized
    fun clearStoriesNow() {
        invalidateStoryDiffs()
        oldScrollState = null
        pendingScrollStoryHash = null
        pendingHighlightStoryHash = null
        returnHighlight?.cancel()
        returnHighlight = null
        activeFeedIds = null
        clusterThumbnailUrls.clear()
        titleCache.clear()
        stories.clear()
        displayItems.clear()
        storyDisplayPositions.clear()
        notifyDataSetChanged()
    }

    fun setStyle(listStyle: StoryListStyle) {
        this.listStyle = listStyle
    }

    fun setThumbnailStyle(thumbnailStyle: ThumbnailStyle) {
        this.thumbnailStyle = thumbnailStyle
    }

    fun setSpacingStyle(spacingStyle: SpacingStyle) {
        this.spacingStyle = spacingStyle
    }

    fun addFooterView(v: View) {
        footerViews.add(v)
    }

    override fun getItemCount(): Int = storyCount + footerViews.size

    val storyCount: Int
        get() = visibleDisplayItemCount()

    val rawStoryCount: Int
        get() = stories.size

    override fun getItemViewType(position: Int): Int {
        if (position >= storyCount) return VIEW_TYPE_FOOTER
        return when (displayItems.getOrNull(position)) {
            is DisplayItem.ClusterRow -> VIEW_TYPE_CLUSTER_ROW
            else ->
                if (listStyle == StoryListStyle.LIST) {
                    VIEW_TYPE_STORY_ROW
                } else {
                    VIEW_TYPE_STORY_TILE
                }
        }
    }

    override fun getItemId(position: Int): Long {
        if (position >= storyCount) {
            return (footerViews[position - storyCount].hashCode().toLong())
        }

        return displayItems.getOrNull(position)?.stableId ?: 0L
    }

    @JvmOverloads
    fun submitStories(
        stories: List<Story>,
        loadId: Long,
        rv: RecyclerView,
        oldScrollState: Parcelable?,
        skipBackFillingStories: Boolean,
        onCommitted: Runnable? = null,
    ) {
        lastLoadId = loadId
        // StoryViewAdapter.kt keeps explicit restoration even when its batch is superseded in the queue.
        oldScrollState?.let { this.oldScrollState = it }
        val runner = diffRunner ?: newDiffRunner().also { diffRunner = it }
        val submission = StorySubmission(stories, loadId, rv, skipBackFillingStories, diffGeneration, onCommitted)
        latestSubmission = submission
        runner.submit(submission)
    }

    private fun newDiffRunner() =
        LatestStoryLoadRunner(
            scope = adapterScope,
            queryDispatcher = diffDispatcher,
            load = ::calculateStoryDiff,
            cancel = {},
            publish = ::commitStoryDiff,
            sameQuery = { first, second -> first.generation == second.generation && first.grid === second.grid },
            onError = { error -> Log.e(this, "error diffing: ${error.message}", error) },
        )

    private fun calculateStoryDiff(submission: StorySubmission): StoryDifference {
        val startedAt = if (BuildConfig.DEBUG) SystemClock.elapsedRealtime() else 0L
        if (BuildConfig.DEBUG) android.util.Log.d("NB.StoryDiff", "start id=${submission.loadId} rows=${submission.stories.size}")
        activeFeedIds = null
        val filtered = applySkipBackfill(submission.stories, submission.skipBackfill)
        val newItems = buildDisplayItems(filtered)
        val oldItems = synchronized(this) { displayItems.toList() }
        val diff = DiffUtil.calculateDiff(DisplayItemDiffer(oldItems, newItems), false)
        if (BuildConfig.DEBUG) android.util.Log.d("NB.StoryDiff", "end id=${submission.loadId} rows=${newItems.size} elapsedMs=${SystemClock.elapsedRealtime() - startedAt}")
        return StoryDifference(submission, filtered, newItems, diff)
    }

    private fun commitStoryDiff(result: StoryDifference) {
        val submission = result.submission
        val rv = submission.grid
        if (submission.generation != diffGeneration || rv.adapter !== this) return
        synchronized(this) {
            val replacingEmptyList = stories.isEmpty() && result.stories.isNotEmpty()
            val startAtFirstStory = replacingEmptyList && oldScrollState == null && pendingScrollStoryHash == null
            clusterThumbnailUrls.clear()
            stories.clear()
            stories.addAll(result.stories)
            displayItems.clear()
            displayItems.addAll(result.items)
            rebuildStoryDisplayPositions()
            committedLoadId = submission.loadId
            result.diff.dispatchUpdatesTo(this)
            val lm = rv.layoutManager
            if (startAtFirstStory) {
                // StoryViewAdapter.kt initially contains only the footer. Preserving that anchor would
                // scroll past every inserted story, leaving the viewport on a blank full-height footer.
                if (lm is LinearLayoutManager) lm.scrollToPositionWithOffset(0, 0) else lm?.scrollToPosition(0)
            }
            if (lm != null && !isUpdatingStories && stories.isNotEmpty()) {
                // StoryViewAdapter.kt restores only requested navigation/configuration state.
                // Wait for the newest snapshot so a partial one cannot consume its saved position.
                // DiffUtil preserves the visible anchor during ordinary read/sync updates.
                oldScrollState?.let {
                    lm.onRestoreInstanceState(it)
                    oldScrollState = null
                }
            }
            applyPendingStoryReturn(rv, replacingEmptyList)
        }
        if (BuildConfig.DEBUG) android.util.Log.d("NB.StoryDiff", "commit id=${submission.loadId} rows=${result.items.size} pending=$isUpdatingStories")
        if (latestSubmission === submission) latestSubmission = null
        submission.onCommitted?.run()
    }

    internal data class StorySubmission(
        val stories: List<Story>,
        val loadId: Long,
        val grid: RecyclerView,
        val skipBackfill: Boolean,
        val generation: Long,
        val onCommitted: Runnable?,
    )

    internal data class StoryDifference(
        val submission: StorySubmission,
        val stories: List<Story>,
        val items: List<DisplayItem>,
        val diff: DiffUtil.DiffResult,
    )

    private fun buildDisplayItems(stories: List<Story>): List<DisplayItem> {
        val showClusterRows = listStyle == StoryListStyle.LIST && StoryClusterDisplayDecision.isStoryClusteringEnabled(prefsRepo)
        val subscribedFeedIds = if (showClusterRows) subscribedFeedIds() else emptySet()
        val isArchiveUser = isArchiveUser()
        val clusterMode = StoryClusterDisplayDecision.clusterMode(prefsRepo)

        return buildList {
            stories.forEachIndexed { storyIndex, story ->
                add(DisplayItem.StoryRow(story, storyIndex))

                if (!showClusterRows || story.isBriefingSummary) return@forEachIndexed

                StoryClusterDisplayDecision.visibleClusterStories(
                    clusterStories = story.clusterStories,
                    subscribedFeedIds = subscribedFeedIds,
                    isPremiumArchive = isArchiveUser,
                    clusterMode = clusterMode,
                ).forEach { clusterStory ->
                    val displayedChild = if (story.read && prefsRepo.isClusterMarkReadEnabled() && !clusterStory.read) {
                        ClusterReadRepository.copyWithReadState(clusterStory, true)
                    } else clusterStory
                    add(DisplayItem.ClusterRow(displayedChild, storyIndex, story.storyHash))
                }
            }
        }
    }

    private fun applySkipBackfill(
        incoming: List<Story>,
        skip: Boolean,
    ): List<Story> {
        if (!skip) return incoming

        val currentHashes = getStoryHashes(stories)
        val threshold: Long =
            when (storyOrder) {
                StoryOrder.NEWEST -> getOldestStoryTimestamp(stories)
                StoryOrder.OLDEST -> getNewestStoryTimestamp(stories)
            }

        return incoming.filter { s ->
            if (s.storyHash in currentHashes) return@filter true
            when (storyOrder) {
                StoryOrder.NEWEST -> s.timestamp < threshold
                StoryOrder.OLDEST -> s.timestamp > threshold
            }
        }
    }

    internal class DisplayItemDiffer(
        private val oldDisplayItems: List<DisplayItem>,
        private val newDisplayItems: List<DisplayItem>,
    ) : DiffUtil.Callback() {
        override fun areContentsTheSame(
            oldItemPosition: Int,
            newItemPosition: Int,
        ): Boolean = newDisplayItems[newItemPosition].contentMatches(oldDisplayItems[oldItemPosition])

        override fun areItemsTheSame(
            oldItemPosition: Int,
            newItemPosition: Int,
        ): Boolean =
            newDisplayItems[newItemPosition].stableId == oldDisplayItems[oldItemPosition].stableId &&
                newDisplayItems[newItemPosition]::class == oldDisplayItems[oldItemPosition]::class

        override fun getNewListSize(): Int = newDisplayItems.size

        override fun getOldListSize(): Int = oldDisplayItems.size

        override fun getChangePayload(oldItemPosition: Int, newItemPosition: Int): Any? {
            val before = oldDisplayItems[oldItemPosition]
            val after = newDisplayItems[newItemPosition]
            return if (before.read != after.read && after.presentationMatches(before)) ReadStatePayload else null
        }
    }

    @Synchronized
    fun getStory(position: Int): Story? =
        if (position >= storyCount || position < 0) {
            null
        } else {
            when (val item = displayItems[position]) {
                is DisplayItem.StoryRow -> item.story
                is DisplayItem.ClusterRow -> stories.getOrNull(item.parentStoryIndex)
            }
        }

    fun getDisplayPositionForStoryIndex(storyIndex: Int): Int =
        storyDisplayPositions.getOrNull(storyIndex) ?: storyIndex

    @Synchronized
    fun getDisplayPositionForStoryHash(storyHash: String?): Int {
        if (storyHash.isNullOrBlank()) return -1

        displayItems.forEachIndexed { index, item ->
            when (item) {
                is DisplayItem.StoryRow -> if (item.story.storyHash == storyHash) return index
                is DisplayItem.ClusterRow -> if (item.clusterStory.storyHash == storyHash) return index
            }
        }

        return -1
    }

    fun setPendingScrollStoryHash(storyHash: String?) {
        pendingScrollStoryHash = storyHash
    }

    fun setPendingHighlightStoryHash(storyHash: String?) {
        pendingHighlightStoryHash = storyHash
    }

    private fun highlightColorForTheme(): Int =
        when (prefsRepo.getResolvedTheme(context)) {
            ThemeValue.SEPIA -> 0xFFEEE0CE.toInt()
            ThemeValue.DARK -> 0xFF606060.toInt()
            ThemeValue.BLACK -> 0xFF606060.toInt()
            else -> 0xFFFFFDEF.toInt()
        }

    private fun defaultColorForTheme(): Int =
        when (prefsRepo.getResolvedTheme(context)) {
            ThemeValue.SEPIA -> 0xFFF3E2CB.toInt()
            ThemeValue.DARK -> 0xFF4F4F4F.toInt()
            ThemeValue.BLACK -> 0xFF000000.toInt()
            else -> 0xFFF4F4F4.toInt()
        }

    @JvmOverloads
    fun requestStoryReturn(storyHash: String?, rv: RecyclerView, presentationReady: Boolean = true) {
        if (storyHash.isNullOrBlank()) return
        if (pendingHighlightStoryHash != storyHash && returnHighlight?.storyHash != storyHash) {
            returnHighlight?.cancel()
            returnHighlight = null
        }
        pendingScrollStoryHash = storyHash
        pendingHighlightStoryHash = storyHash
        returnPresentationReady = presentationReady
        applyPendingStoryReturn(rv)
        rv.invalidate()
    }

    @JvmOverloads
    fun applyPendingStoryReturn(rv: RecyclerView, replacingEmptyList: Boolean = false, presentationFrame: Boolean = false) {
        if (isUpdatingStories || stories.isEmpty() || rv.adapter !== this) return
        val lm = rv.layoutManager ?: return
        pendingScrollStoryHash?.let { hash ->
            val position = getDisplayPositionForStoryHash(hash)
            if (position >= 0) {
                val llm = lm as? LinearLayoutManager
                val first = llm?.findFirstVisibleItemPosition() ?: -1
                val last = llm?.findLastVisibleItemPosition() ?: -1
                if (replacingEmptyList || ReturnedStoryScrollDecider.shouldScrollToReturnedStory(position, first, last)) {
                    if (llm != null) llm.scrollToPositionWithOffset(position, (rv.height * 0.15f).toInt())
                    else lm.scrollToPosition(position)
                }
                // StoryViewAdapter.kt retains the identity until its page exists in a committed batch.
                pendingScrollStoryHash = null
            }
        }
        val hash = pendingHighlightStoryHash ?: return
        if (pendingScrollStoryHash != null || rv.isComputingLayout || rv.isLayoutRequested) return
        val position = getDisplayPositionForStoryHash(hash)
        if (position < 0) return
        val holder = rv.findViewHolderForAdapterPosition(position) ?: return
        if (boundStoryHash(holder) != hash || !holder.itemView.isLaidOut) return
        holdReturnHighlight(holder, hash)
        // StoryViewAdapter.kt starts time only after Reader's exit completed and this window can be seen.
        if (!presentationFrame || !returnPresentationReady || !rv.hasWindowFocus() || !rv.isShown) return
        pendingHighlightStoryHash = null
        animateReturnHighlight(rv, position)
    }

    private fun boundStoryHash(holder: RecyclerView.ViewHolder): String? = when (holder) {
        is StoryViewHolder -> holder.story?.storyHash
        is ClusterRowViewHolder -> holder.clusterStory?.storyHash
        else -> null
    }

    private fun holdReturnHighlight(holder: RecyclerView.ViewHolder, hash: String) {
        if (returnHighlight?.view === holder.itemView && returnHighlight?.storyHash == hash && returnHighlight?.isFinished == false) return
        returnHighlight?.cancel()
        returnHighlight = ReturnedStoryHighlight(
            holder.itemView, hash, { boundStoryHash(holder) }, highlightColorForTheme(), defaultColorForTheme(),
        ).also { it.hold() }
    }

    private fun openHighlightedStory(holder: RecyclerView.ViewHolder, feedSet: FeedSet?, hash: String) {
        // StoryViewAdapter.kt is also used by Daily Briefing, which has no story-list return lifecycle.
        if (fs?.isDailyBriefing == true) {
            listener.onStoryClicked(feedSet, hash)
            return
        }
        // StoryViewAdapter.kt holds the tap through launch; only the existing reader-return path starts its fade.
        pendingScrollStoryHash = null
        pendingHighlightStoryHash = null
        returnPresentationReady = false
        returnHighlight?.cancel()
        returnHighlight = null
        holdReturnHighlight(holder, hash)
        try {
            listener.onStoryClicked(feedSet, hash)
        } catch (exception: RuntimeException) {
            cancelReturnHighlight(holder)
            throw exception
        }
    }

    private fun animateReturnHighlight(rv: RecyclerView, position: Int) {
        val holder = rv.findViewHolderForAdapterPosition(position) ?: return
        val hash = boundStoryHash(holder) ?: return
        if (returnHighlight?.view === holder.itemView && returnHighlight?.storyHash == hash) returnHighlight?.fade()
    }

    private fun cancelReturnHighlight(holder: RecyclerView.ViewHolder) {
        if (returnHighlight?.view !== holder.itemView) return
        returnHighlight?.cancel()
        returnHighlight = null
    }

    override fun onAttachedToRecyclerView(recyclerView: RecyclerView) {
        super.onAttachedToRecyclerView(recyclerView)
        returnObserver = recyclerView.viewTreeObserver
        returnPreDrawListener = ViewTreeObserver.OnPreDrawListener {
            if (pendingScrollStoryHash != null || pendingHighlightStoryHash != null) applyPendingStoryReturn(recyclerView, presentationFrame = true)
            true
        }.also { returnObserver?.addOnPreDrawListener(it) }
        returnFocusListener = ViewTreeObserver.OnWindowFocusChangeListener { focused ->
            if (focused) recyclerView.invalidate()
        }.also { returnObserver?.addOnWindowFocusChangeListener(it) }
    }

    fun setTextSize(textSize: Float) {
        this.textSize = textSize
    }

    override fun onCreateViewHolder(
        viewGroup: ViewGroup,
        viewType: Int,
    ): RecyclerView.ViewHolder {
        // StoryViewAdapter.kt retains the existing layer choice; debug builds allow a profiling A/B.
        if (viewType == VIEW_TYPE_STORY_TILE) {
            val v = LayoutInflater.from(viewGroup.context).inflate(R.layout.view_story_tile, viewGroup, false)
            if (useHardwareRowLayers) v.setLayerType(View.LAYER_TYPE_HARDWARE, null)
            return StoryTileViewHolder(v)
        } else if (viewType == VIEW_TYPE_CLUSTER_ROW) {
            val v = LayoutInflater.from(viewGroup.context).inflate(R.layout.view_story_cluster_row, viewGroup, false)
            return ClusterRowViewHolder(v)
        } else if (viewType == VIEW_TYPE_STORY_ROW) {
            val v = LayoutInflater.from(viewGroup.context).inflate(R.layout.view_story_row, viewGroup, false)
            if (useHardwareRowLayers) v.setLayerType(View.LAYER_TYPE_HARDWARE, null)
            return StoryRowViewHolder(v)
        } else {
            val v = LayoutInflater.from(viewGroup.context).inflate(R.layout.view_footer_tile, viewGroup, false)
            return FooterViewHolder(v)
        }
    }

    override fun onDetachedFromRecyclerView(recyclerView: RecyclerView) {
        super.onDetachedFromRecyclerView(recyclerView)
        recyclerView.viewTreeObserver.takeIf { it.isAlive }?.let { observer ->
            returnPreDrawListener?.let(observer::removeOnPreDrawListener)
            returnFocusListener?.let(observer::removeOnWindowFocusChangeListener)
        }
        returnObserver = null
        returnPreDrawListener = null
        returnFocusListener = null
        returnHighlight?.cancel()
        returnHighlight = null
        invalidateStoryDiffs()
        diffRunner?.close()
        diffRunner = null
    }

    open inner class StoryViewHolder(
        view: View,
    ) : RecyclerView.ViewHolder(view),
        View.OnClickListener,
        OnCreateContextMenuListener,
        MenuItem.OnMenuItemClickListener,
        OnTouchListener {
        val leftBarOne: View = view.findViewById(R.id.story_item_favicon_borderbar_1)
        val leftBarTwo: View = view.findViewById(R.id.story_item_favicon_borderbar_2)
        val intelDot: ImageView = view.findViewById(R.id.story_item_inteldot)
        val thumbViewRight: StoryThumbnailView? = view.findViewById(R.id.story_item_thumbnail_right)
        val thumbViewLeft: StoryThumbnailView? = view.findViewById(R.id.story_item_thumbnail_left)
        val thumbTileView: ImageView? = view.findViewById(R.id.story_item_thumbnail)
        val feedIconView: ImageView = view.findViewById(R.id.story_item_feedicon)
        val feedTitleView: TextView = view.findViewById(R.id.story_item_feedtitle)
        val storyTitleView: TextView = view.findViewById(R.id.story_item_title)
        val storyDate: TextView = view.findViewById(R.id.story_item_date)
        val savedView: View = view.findViewById(R.id.story_item_saved_icon)
        val sharedView: View = view.findViewById(R.id.story_item_shared_icon)

        var story: Story? = null
        private var storyMenu: PopupWindow? = null

        fun dismissStoryMenu() {
            storyMenu?.dismiss()
            storyMenu = null
        }

        var thumbLoader: PhotoToLoad? = null
        var lastThumbUrl: String? = null
        var lastThumbView: ImageView? = null
        internal val readStateAnimator = StoryReadStateAnimator()
        var gestureR2L: Boolean = false
        var gestureL2R: Boolean = false
        var gestureDebounce: Boolean = false

        private val rowSwipe =
            com.newsblur.view.RowSwipeGesture(
                itemView,
                action = { right ->
                    if (!prefsRepo.isStorySwipesEnabled() ||
                        (
                            right &&
                                context is ItemsList &&
                                prefsRepo.getLeftToRightGestureAction() == GestureAction.GEST_ACTION_BACK
                        )
                    ) {
                        null
                    } else {
                        story?.let { target ->
                            com.newsblur.util.GestureSwipeAction.resolve(
                                swipeAction(right),
                                isRead = target.read,
                                isSaved = target.starred,
                            )
                        }
                    }
                },
                perform = { performGesture(it.action) },
                claim = { gestureDebounce = true },
                colors = {
                    com.newsblur.util.GestureThemeStyle
                        .palette(prefsRepo.getResolvedTheme(context))
                },
            )
        private var gestureStoryHash: String? = null
        private var edgeGesture = false

        fun cancelRowSwipe() = rowSwipe.cancel()

        private fun swipeAction(right: Boolean) =
            if (right) prefsRepo.getLeftToRightGestureAction() else prefsRepo.getRightToLeftGestureAction()

        init {
            view.setOnClickListener(this)
            view.setOnCreateContextMenuListener(this)
            view.setOnLongClickListener {
                rowSwipe.cancel()
                gestureDebounce = false
                performGesture(prefsRepo.getStoryLongPressAction())
                true
            }

            view.setOnTouchListener(this)
        }

        override fun onClick(view: View) {
            // clicks like to get accidentally triggered by the system right after we detect
            // a gesture. ignore if a gesture appears to be in progress.
            if (gestureDebounce) {
                gestureDebounce = false
                return
            }
            if (gestureL2R || gestureR2L) return
            val hash = story?.storyHash?.takeIf { it.isNotBlank() } ?: return
            val now = SystemClock.elapsedRealtime()
            if (now - lastStoryOpenElapsedRealtime < ViewConfiguration.getDoubleTapTimeout().toLong()) return
            lastStoryOpenElapsedRealtime = now
            openHighlightedStory(this, fs, hash)
        }

        override fun onCreateContextMenu(
            menu: ContextMenu,
            v: View,
            menuInfo: ContextMenuInfo?,
        ) {
            // clicks like to get accidentally triggered by the system right after we detect
            // a gesture. ignore if a gesture appears to be in progress.
            if (gestureDebounce) {
                gestureDebounce = false
                return
            }
            if (gestureL2R || gestureR2L) return
            val inflater = MenuInflater(context)
            val storyOrder = fs?.let { prefsRepo.getStoryOrder(it) } ?: StoryOrder.NEWEST
            UIUtils.inflateStoryContextMenu(menu, inflater, fs, story, storyOrder)
            for (i in 0 until menu.size()) {
                menu.getItem(i).setOnMenuItemClickListener(this)
            }
        }

        override fun onMenuItemClick(item: MenuItem): Boolean {
            if (item.itemId == R.id.menu_mark_story_as_read) {
                feedUtils.markStoryAsRead(story!!, context)
                return true
            } else if (item.itemId == R.id.menu_mark_story_as_unread) {
                feedUtils.markStoryUnread(story!!, context)
                return true
            } else if (item.itemId == R.id.menu_mark_older_stories_as_read) {
                feedUtils.markRead(context, fs!!, story!!.timestamp, null, R.array.mark_older_read_options)
                return true
            } else if (item.itemId == R.id.menu_mark_newer_stories_as_read) {
                feedUtils.markRead(context, fs!!, null, story!!.timestamp, R.array.mark_newer_read_options)
                return true
            } else if (item.itemId == R.id.menu_send_story) {
                feedUtils.sendStoryUrl(story, context)
                return true
            } else if (item.itemId == R.id.menu_send_story_full) {
                feedUtils.sendStoryFull(story, context)
                return true
            } else if (item.itemId == R.id.menu_save_story) {
                // TODO get folder name
                feedUtils.setStorySaved(story!!, true, context, emptyList(), emptyList())
                return true
            } else if (item.itemId == R.id.menu_unsave_story) {
                feedUtils.setStorySaved(story!!, false, context, emptyList(), emptyList())
                return true
            } else if (item.itemId == R.id.menu_intel) {
                if (story!!.feedId == "0") return true // cannot train on feedless stories

                val intelFrag = StoryIntelTrainerFragment.newInstance(story, fs)
                intelFrag.show(context.supportFragmentManager, StoryIntelTrainerFragment::class.java.name)
                return true
            } else if (item.itemId == R.id.menu_go_to_feed) {
                val targetFeedSet = FeedSet.singleFeed(story!!.feedId)
                val folderName = targetFeedFolderName()
                feedUtils.currentFolderName =
                    if (folderName == AppConstants.ROOT_FOLDER) {
                        null
                    } else {
                        folderName
                    }
                FeedItemsList.startActivity(
                    context,
                    targetFeedSet,
                    feedUtils.getFeed(story!!.feedId),
                    folderName,
                    null,
                    null,
                )
                return true
            } else {
                return false
            }
        }

        private fun targetFeedFolderName(): String =
            when {
                fs?.isFolder == true -> fs?.folderName ?: AppConstants.ROOT_FOLDER
                !feedUtils.currentFolderName.isNullOrEmpty() -> feedUtils.currentFolderName!!
                else -> AppConstants.ROOT_FOLDER
            }

        override fun onTouch(
            v: View,
            event: MotionEvent,
        ): Boolean {
            if (event.actionMasked == MotionEvent.ACTION_DOWN) {
                gestureDebounce = false
                gestureStoryHash = story?.storyHash
                val paneOrigin = IntArray(2)
                (itemView.parent as? View)?.getLocationOnScreen(paneOrigin)
                edgeGesture = context is ItemsList && event.rawX - paneOrigin[0] < UIUtils.dp2px(context, 24)
            }
            if (edgeGesture || gestureStoryHash != story?.storyHash) {
                rowSwipe.cancel()
                return false
            }
            return rowSwipe.onTouch(event)
        }

        private fun performGesture(action: GestureAction) {
            val target = story ?: return
            when (action) {
                GestureAction.GEST_ACTION_BACK -> (context as? ItemsList)?.completeInteractiveStoryListSwipe()
                GestureAction.GEST_ACTION_TOGGLE_READ -> toggleStoryReadState()
                GestureAction.GEST_ACTION_MARKREAD -> feedUtils.markStoryAsRead(target, context)
                GestureAction.GEST_ACTION_MARKUNREAD -> feedUtils.markStoryUnread(target, context)
                GestureAction.GEST_ACTION_SAVE -> feedUtils.setStorySaved(target, true, context, emptyList(), emptyList())
                GestureAction.GEST_ACTION_UNSAVE -> feedUtils.setStorySaved(target, false, context, emptyList(), emptyList())
                GestureAction.GEST_ACTION_TOGGLE_SAVE -> feedUtils.setStorySaved(target, !target.starred, context, emptyList(), emptyList())
                GestureAction.GEST_ACTION_STATISTICS -> feedUtils.openStatistics(context, prefsRepo, target.feedId)
                GestureAction.GEST_ACTION_SHARE -> feedUtils.sendStoryUrl(target, context)
                GestureAction.GEST_ACTION_MENU -> {
                    gestureDebounce = false
                    dismissStoryMenu()
                    storyMenu = StoryMenuPopover.show(
                        context,
                        itemView.findViewById<View>(R.id.story_item_title) ?: itemView,
                        itemView,
                        fs ?: return,
                        target,
                        fs?.let { prefsRepo.getStoryOrder(it) } ?: StoryOrder.NEWEST,
                        prefsRepo.getResolvedTheme(context),
                    ) { item ->
                        if (story?.storyHash == target.storyHash) onMenuItemClick(item) else false
                    }
                }
                GestureAction.GEST_ACTION_TRAIN ->
                    if (target.feedId != "0") {
                        StoryIntelTrainerFragment
                            .newInstance(
                                target,
                                fs,
                            ).show(context.supportFragmentManager, StoryIntelTrainerFragment::class.java.name)
                    }
                GestureAction.GEST_ACTION_ASK_AI -> {
                    val tag = com.newsblur.askai.AskAiBottomSheetFragment.TAG
                    if (context.supportFragmentManager.findFragmentByTag(tag) == null) {
                        com.newsblur.askai.AskAiBottomSheetFragment
                            .newInstance(target.storyHash, UIUtils.fromHtml(target.title).toString())
                            .show(context.supportFragmentManager, tag)
                    }
                }
                else -> Unit
            }
        }

        private fun toggleStoryReadState() {
            val targetStory = story ?: return
            if (targetStory.read) {
                feedUtils.markStoryUnread(targetStory, context)
            } else {
                feedUtils.markStoryAsRead(targetStory, context)
            }
        }
    }

    inner class StoryTileViewHolder(
        view: View,
    ) : StoryViewHolder(view)

    inner class StoryRowViewHolder(
        view: View,
    ) : StoryViewHolder(view) {
        var storyAuthor: TextView = view.findViewById(R.id.story_item_author)
        var storySnippet: TextView = view.findViewById(R.id.story_item_content)
    }

    inner class ClusterRowViewHolder(
        view: View,
    ) : RecyclerView.ViewHolder(view),
        View.OnClickListener {
        val root: View = view.findViewById(R.id.story_cluster_row_root)
        val card: View = view.findViewById(R.id.story_cluster_row_card)
        val outerBar: View = view.findViewById(R.id.story_cluster_row_bar_outer)
        val innerBar: View = view.findViewById(R.id.story_cluster_row_bar_inner)
        val sentiment: ImageView = view.findViewById(R.id.story_cluster_row_sentiment)
        val feedIcon: ImageView = view.findViewById(R.id.story_cluster_row_feed_icon)
        val preview: StoryThumbnailView = view.findViewById(R.id.story_cluster_row_preview)
        val badge: TextView = view.findViewById(R.id.story_cluster_row_badge)
        val title: TextView = view.findViewById(R.id.story_cluster_row_title)
        val date: TextView = view.findViewById(R.id.story_cluster_row_date)

        var clusterStory: Story.ClusterStory? = null
        var previewLoader: PhotoToLoad? = null
        internal val readStateAnimator = StoryReadStateAnimator()

        init {
            view.setOnClickListener(this)
        }

        override fun onClick(v: View) {
            val story = clusterStory ?: return
            val now = SystemClock.elapsedRealtime()
            if (now - lastStoryOpenElapsedRealtime < ViewConfiguration.getDoubleTapTimeout().toLong()) return
            val feedId = story.feedId ?: return
            val storyHash = story.storyHash ?: return
            lastStoryOpenElapsedRealtime = now

            when (
                val target =
                    StoryClusterNavigationDecision.resolve(
                        currentFeedSet = fs,
                        currentFolderName = feedUtils.currentFolderName,
                        targetFeedId = feedId,
                        storyHash = storyHash,
                    )
            ) {
                is StoryClusterNavigationTarget.DirectReading -> {
                    openHighlightedStory(this, target.feedSet, target.storyHash)
                }

                is StoryClusterNavigationTarget.FeedListReading -> {
                    val feed = feedUtils.getFeed(feedId)
                    if (feed == null) {
                        openHighlightedStory(this, target.feedSet, target.storyHash)
                        return
                    }
                    feedUtils.currentFolderName =
                        if (target.folderName == AppConstants.ROOT_FOLDER) {
                            null
                        } else {
                            target.folderName
                        }
                    FeedItemsList.startStoryActivity(context, target.feedSet, feed, target.folderName, target.storyHash)
                }

                null -> Unit
            }
        }
    }

    override fun onBindViewHolder(
        viewHolder: RecyclerView.ViewHolder,
        position: Int,
        payloads: MutableList<Any>,
    ) {
        if (payloads.isNotEmpty() && payloads.all { it === ReadStatePayload }) {
            when (val item = displayItems.getOrNull(position)) {
                is DisplayItem.StoryRow -> if (viewHolder is StoryViewHolder && viewHolder.story?.storyHash == item.story.storyHash) {
                    viewHolder.story = item.story
                    bindReadState(viewHolder, item.story, animated = true)
                    return
                }
                is DisplayItem.ClusterRow -> if (viewHolder is ClusterRowViewHolder && viewHolder.clusterStory?.storyHash == item.clusterStory.storyHash) {
                    viewHolder.clusterStory = item.clusterStory
                    bindClusterReadState(viewHolder, item.clusterStory, animated = true)
                    return
                }
                null -> Unit
            }
        }
        onBindViewHolder(viewHolder, position)
    }

    override fun onBindViewHolder(
        viewHolder: RecyclerView.ViewHolder,
        position: Int,
    ) {
        val incomingHash = when (val item = displayItems.getOrNull(position)) {
            is DisplayItem.StoryRow -> item.story.storyHash
            is DisplayItem.ClusterRow -> item.clusterStory.storyHash
            else -> null
        }
        val retainedHighlight = returnHighlight?.takeIf {
            it.view === viewHolder.itemView && it.storyHash == incomingHash && !it.isFinished
        }
        if (retainedHighlight != null) retainedHighlight.beforeRebind() else cancelReturnHighlight(viewHolder)
        if (position >= storyCount || position < 0) {
            val vh = viewHolder as FooterViewHolder
            vh.innerView.removeAllViews()
            val targetFooter = footerViews[position - storyCount]

            // footers often move aboslute position, but views can only have one parent. since the RV doesn't
            // necessarily remove from the old pos before adding to the new, we have to add a check here.
            // however, modifying other views out of order causes requestLayout to be called from within a
            // layout pass, which causes warnings.
            val oldFooterHolder = targetFooter.parent
            if (oldFooterHolder is ViewGroup) oldFooterHolder.removeAllViews()

            vh.innerView.addView(targetFooter)
            return
        }

        when (val item = displayItems[position]) {
            is DisplayItem.StoryRow -> {
                val story = item.story
                val storyHolder = viewHolder as StoryViewHolder
                if (storyHolder.story?.storyHash != story.storyHash) {
                    storyHolder.dismissStoryMenu()
                    storyHolder.cancelRowSwipe()
                }
                storyHolder.story = story
                bindCommon(storyHolder, story)

                if (storyHolder is StoryRowViewHolder) {
                    bindRow(storyHolder, story)
                } else {
                    bindTile(storyHolder as StoryTileViewHolder, story)
                }
                bindReadState(storyHolder, story, animated = false)
            }
            is DisplayItem.ClusterRow -> {
                bindClusterRow(viewHolder as ClusterRowViewHolder, item)
            }
        }
        retainedHighlight?.afterRebind()
    }

    /**
     * Bind view elements that are common to tiles and rows.
     */
    private fun bindCommon(
        vh: StoryViewHolder,
        story: Story,
    ) {
        vh.readStateAnimator.cancel()
        vh.itemView.setBackgroundResource(backgroundResourceFor(story))
        vh.leftBarOne.setBackgroundColor(UIUtils.decodeColourValue(story.extern_feedColor, Color.GRAY))
        vh.leftBarTwo.setBackgroundColor(UIUtils.decodeColourValue(story.extern_feedFade, Color.LTGRAY))

        if (!ignoreIntel) {
            val score = story.extern_intelTotalScore
            if (score > 0) {
                vh.intelDot.setImageResource(R.drawable.ic_indicator_focus)
            } else if (score == 0) {
                vh.intelDot.setImageResource(R.drawable.ic_indicator_unread)
            } else {
                vh.intelDot.setImageResource(R.drawable.ic_indicator_hidden)
            }
        } else {
            vh.intelDot.setImageResource(android.R.color.transparent)
        }

        vh.storyTitleView.text = titleCache.get(story.title)
        vh.storyDate.text = StoryUtils.formatShortDate(context, story.timestamp)

        // lists with mixed feeds get added info, but single feeds do not
        if (!singleFeed) {
            // Check for custom feed icon
            val customFeedIcon: CustomIcon? = BlurDatabaseHelper.getFeedIcon(story.feedId)
            if (customFeedIcon != null) {
                val iconSize = UIUtils.dp2px(context, 18)
                val iconBitmap = CustomIconRenderer.renderIcon(context, customFeedIcon, iconSize)
                if (iconBitmap != null) {
                    vh.feedIconView.setImageBitmap(iconBitmap)
                } else {
                    iconLoader.displayImage(story.extern_faviconUrl, vh.feedIconView)
                }
            } else {
                iconLoader.displayImage(story.extern_faviconUrl, vh.feedIconView)
            }
            vh.feedTitleView.text = story.extern_feedTitle
            vh.feedIconView.visibility = View.VISIBLE
            vh.feedTitleView.visibility = View.VISIBLE
        } else {
            vh.feedIconView.visibility = View.GONE
            vh.feedTitleView.visibility = View.GONE
        }

        if (story.starred) {
            vh.savedView.visibility = View.VISIBLE
        } else {
            vh.savedView.visibility = View.GONE
        }

        var shared = false
        findShareLoop@ for (userId in story.sharedUserIds) {
            if (userId == this.userId) {
                shared = true
                break@findShareLoop
            }
        }
        if (shared) {
            vh.sharedView.visibility = View.VISIBLE
        } else {
            vh.sharedView.visibility = View.GONE
        }

        // dynamic text sizing
        vh.feedTitleView.textSize = textSize * DEFAULT_TEXT_SIZE_STORY_FEED_TITLE
        vh.storyTitleView.textSize = textSize * DEFAULT_TEXT_SIZE_STORY_TITLE
        vh.storyDate.textSize = textSize * DEFAULT_TEXT_SIZE_STORY_DATE_OR_AUTHOR
        vh.feedTitleView.setTypeface(vh.feedTitleView.typeface, Typeface.BOLD)
        vh.storyTitleView.setTypeface(vh.storyTitleView.typeface, Typeface.BOLD)
        vh.storyDate.setTypeface(vh.storyDate.typeface, Typeface.NORMAL)

        // dynamic spacing
        val verticalTitlePadding = spacingStyle.getStoryTitleVerticalPadding(context)
        val rightTitlePadding = spacingStyle.getStoryContentRightPadding(context, thumbnailStyle)
        vh.storyTitleView.setPadding(
            vh.storyTitleView.paddingLeft,
            verticalTitlePadding,
            rightTitlePadding,
            verticalTitlePadding,
        )

    }

    private fun bindReadState(vh: StoryViewHolder, story: Story, animated: Boolean) {
        val isRead = !ignoreReadStatus && story.read
        val theme = prefsRepo.getResolvedTheme(context)
        val headingColor = StoryRowPalette.feedTitleArgb(theme, isRead)
        val metadataColor = StoryRowPalette.metadataArgb(theme, isRead)
        val textColors = mutableListOf(vh.feedTitleView to headingColor, vh.storyTitleView to headingColor, vh.storyDate to metadataColor)
        if (vh is StoryRowViewHolder) {
            textColors += vh.storyAuthor to metadataColor
            textColors += vh.storySnippet to metadataColor
        }
        textColors.forEach { it.first.alpha = 1f }
        val imageAlpha = if (isRead) READ_STORY_ALPHA_B255 else 255
        val images = listOfNotNull(vh.intelDot, vh.feedIconView, vh.thumbViewLeft, vh.thumbViewRight, vh.thumbTileView)
        vh.readStateAnimator.update(
            textColors = textColors,
            imageAlphas = images.map { it to imageAlpha },
            drawableAlphas = listOfNotNull(vh.leftBarOne.background, vh.leftBarTwo.background).map { it to imageAlpha },
            animated = animated,
        )
    }

    private fun bindTile(
        vh: StoryTileViewHolder,
        story: Story,
    ) {
        // when first created, tiles' views tend to not yet have their dimensions calculated, but
        // upon being recycled they will often have a known size, which lets us give a max size to
        // the image loader, which in turn can massively optimise loading.  the image loader will
        // reject nonsene values

        if (!thumbnailStyle.isOff() && vh.thumbTileView != null) {
            // the view will display a stale, recycled thumb before the new one loads if the old is not cleared
            val thumbSizeGuess = vh.thumbTileView.measuredHeight
            bindThumbnail(vh, vh.thumbTileView, story.thumbnailUrl, thumbSizeGuess)
        }
    }

    private fun bindThumbnail(vh: StoryViewHolder, target: ImageView, url: String?, size: Int) {
        if (vh.lastThumbView === target && vh.lastThumbUrl == url && vh.thumbLoader?.cancel == false) return
        vh.thumbLoader?.cancel = true
        target.setImageBitmap(null)
        vh.thumbLoader = thumbnailLoader.displayImage(url, target, size, true)
        vh.lastThumbView = target
        vh.lastThumbUrl = url
    }

    private fun bindRow(
        vh: StoryRowViewHolder,
        story: Story,
    ) {
        val storyContentPreviewStyle = prefsRepo.getStoryContentPreviewStyle()
        val showRightThumbnail = thumbnailStyle.isRight() && !TextUtils.isEmpty(story.thumbnailUrl)

        if (storyContentPreviewStyle != StoryContentPreviewStyle.NONE) {
            vh.storyTitleView.maxLines = 3
            if (storyContentPreviewStyle == StoryContentPreviewStyle.LARGE) {
                vh.storySnippet.maxLines = 6
            } else if (storyContentPreviewStyle == StoryContentPreviewStyle.MEDIUM) {
                vh.storySnippet.maxLines = 4
            } else if (storyContentPreviewStyle == StoryContentPreviewStyle.SMALL) {
                vh.storySnippet.maxLines = 2
            }
            if (!TextUtils.isEmpty(story.shortContent)) {
                vh.storySnippet.visibility = View.VISIBLE
                vh.storySnippet.text = story.shortContent
            } else {
                vh.storySnippet.visibility = View.GONE
            }
        } else {
            vh.storyTitleView.maxLines = 6
            vh.storySnippet.visibility = View.GONE
        }

        if (TextUtils.isEmpty(story.authors)) {
            vh.storyAuthor.text = ""
        } else {
            vh.storyAuthor.text = vh.storyAuthor.context.getString(R.string.story_author, story.authors)
        }

        vh.storyAuthor.textSize = textSize * DEFAULT_TEXT_SIZE_STORY_DATE_OR_AUTHOR
        vh.storySnippet.textSize = textSize * DEFAULT_TEXT_SIZE_STORY_SNIP
        vh.storyAuthor.setTypeface(vh.storyAuthor.typeface, Typeface.NORMAL)
        vh.storySnippet.setTypeface(vh.storySnippet.typeface, Typeface.NORMAL)

        val contentRightPadding =
            spacingStyle.getStoryContentRightPadding(
                context,
                if (showRightThumbnail) thumbnailStyle else ThumbnailStyle.OFF,
            )
        val titleVerticalPadding = spacingStyle.getStoryTitleVerticalPadding(context)
        vh.storyTitleView.setPadding(
            vh.storyTitleView.paddingLeft,
            titleVerticalPadding,
            contentRightPadding,
            titleVerticalPadding,
        )
        val contentVerticalPadding = spacingStyle.getStoryContentVerticalPadding(context)
        vh.storySnippet.setPadding(
            vh.storySnippet.paddingLeft,
            vh.storySnippet.paddingTop,
            contentRightPadding,
            contentVerticalPadding,
        )

        val verticalContainerMargin = spacingStyle.getStoryContainerMargin(context)
        val feedIconLp = vh.feedIconView.layoutParams as RelativeLayout.LayoutParams
        feedIconLp.setMargins(feedIconLp.leftMargin, verticalContainerMargin, feedIconLp.rightMargin, feedIconLp.bottomMargin)
        val feedTitleLp = vh.feedTitleView.layoutParams as RelativeLayout.LayoutParams
        feedTitleLp.setMargins(feedTitleLp.leftMargin, verticalContainerMargin, feedTitleLp.rightMargin, feedTitleLp.bottomMargin)
        val storyDateLp = vh.storyDate.layoutParams as RelativeLayout.LayoutParams
        storyDateLp.setMargins(storyDateLp.leftMargin, storyDateLp.topMargin, storyDateLp.rightMargin, verticalContainerMargin)

        if (!thumbnailStyle.isOff() && vh.thumbViewRight != null && vh.thumbViewLeft != null) {
            // the view will display a stale, recycled thumb before the new one loads if the old is not cleared
            if (thumbnailStyle.isLeft()) {
                val thumbSizeGuess = vh.thumbViewLeft.measuredHeight
                bindThumbnail(vh, vh.thumbViewLeft, story.thumbnailUrl, thumbSizeGuess)
                vh.thumbViewRight.visibility = View.GONE
                vh.thumbViewLeft.visibility = View.VISIBLE
            } else if (thumbnailStyle.isRight()) {
                val thumbSizeGuess = vh.thumbViewRight.measuredHeight
                vh.thumbViewLeft.visibility = View.GONE
                if (showRightThumbnail) {
                    bindThumbnail(vh, vh.thumbViewRight, story.thumbnailUrl, thumbSizeGuess)
                    vh.thumbViewRight.visibility = View.VISIBLE
                } else {
                    vh.thumbLoader?.cancel = true
                    vh.lastThumbView = null
                    vh.thumbViewRight.visibility = View.GONE
                }
            }
        } else if (vh.thumbViewRight != null && vh.thumbViewLeft != null) {
            vh.thumbLoader?.cancel = true
            vh.lastThumbView = null
            // if in row mode and thumbnail is disabled or missing, don't just hide but collapse
            vh.thumbViewRight.visibility = View.GONE
            vh.thumbViewLeft.visibility = View.GONE
        }

        val largeWidthPx = context.resources.getDimensionPixelSize(R.dimen.thumbnails_size)
        val smallWidthPx = context.resources.getDimensionPixelSize(R.dimen.thumbnails_small_width)
        val smallMinHeightPx = context.resources.getDimensionPixelSize(R.dimen.thumbnails_small_min_height)

        var params: RelativeLayout.LayoutParams? = null
        var thumbView: StoryThumbnailView? = null
        if (thumbnailStyle.isLeft() && vh.thumbViewLeft != null) {
            vh.thumbViewLeft.setThumbnailStyle(thumbnailStyle)
            thumbView = vh.thumbViewLeft
            params = vh.thumbViewLeft.layoutParams as RelativeLayout.LayoutParams
        } else if (thumbnailStyle.isRight() && vh.thumbViewRight != null) {
            vh.thumbViewRight.setThumbnailStyle(thumbnailStyle)
            thumbView = vh.thumbViewRight
            params = vh.thumbViewRight.layoutParams as RelativeLayout.LayoutParams
        }
        if (params != null) {
            val verticalMargin = if (singleFeed) verticalContainerMargin + UIUtils.dp2px(context, 2) else verticalContainerMargin
            val sideMargin = UIUtils.dp2px(context, 8)
            val layout = thumbnailStyle.storyRowLayout(largeWidthPx, smallWidthPx, verticalMargin, sideMargin)

            params.removeRule(RelativeLayout.ALIGN_BOTTOM)
            params.removeRule(RelativeLayout.CENTER_VERTICAL)
            params.removeRule(RelativeLayout.ALIGN_PARENT_TOP)
            params.removeRule(RelativeLayout.ALIGN_PARENT_BOTTOM)

            when (layout.verticalMode) {
                StoryRowThumbnailVerticalMode.CENTERED -> {
                    params.addRule(RelativeLayout.CENTER_VERTICAL)
                    val targetThumbView = thumbView
                    if (targetThumbView != null) {
                        val boundStoryHash = story.storyHash
                        val boundThumbnailStyle = thumbnailStyle
                        val verticalInsetPx = UIUtils.dp2px(context, 8)

                        // For recycled views that already have a measured height, compute the
                        // target thumbnail height immediately so the view never appears as a
                        // 1px sliver.  Fresh views use the minimum thumbnail height as a
                        // reasonable default; the doOnLayout callback corrects it later.
                        val existingHeight = vh.itemView.height
                        val initialHeight = if (existingHeight > 0) {
                            val maxAllowed = (existingHeight - verticalInsetPx).coerceAtLeast(1)
                            val scaled = (existingHeight * layout.rowHeightFraction).roundToInt()
                            if (maxAllowed >= smallMinHeightPx) {
                                scaled.coerceAtLeast(smallMinHeightPx).coerceAtMost(maxAllowed)
                            } else {
                                maxAllowed
                            }
                        } else {
                            smallMinHeightPx
                        }

                        targetThumbView.setExpandedLayout(
                            layout.widthPx,
                            initialHeight,
                            layout.leftMarginPx,
                            layout.topMarginPx,
                            layout.rightMarginPx,
                            layout.bottomMarginPx,
                        )
                        vh.itemView.doOnLayout { itemView ->
                            if (vh.story?.storyHash != boundStoryHash) return@doOnLayout
                            if (thumbnailStyle != boundThumbnailStyle) return@doOnLayout
                            val maxAllowedHeight = (itemView.height - verticalInsetPx).coerceAtLeast(1)
                            val scaledHeight = (itemView.height * layout.rowHeightFraction).roundToInt()
                            val targetHeight =
                                if (maxAllowedHeight >= smallMinHeightPx) {
                                    scaledHeight.coerceAtLeast(smallMinHeightPx).coerceAtMost(maxAllowedHeight)
                                } else {
                                    maxAllowedHeight
                                }
                            targetThumbView.setExpandedLayout(
                                layout.widthPx,
                                targetHeight,
                                layout.leftMarginPx,
                                layout.topMarginPx,
                                layout.rightMarginPx,
                                layout.bottomMarginPx,
                            )
                            // RecyclerView suppresses requestLayout() during its layout pass,
                            // so setExpandedLayout's resize may be silently dropped for views
                            // first entering the viewport.  Post a deferred requestLayout as
                            // a fallback once the suppression window has closed.
                            if (targetThumbView.height != targetHeight) {
                                targetThumbView.post {
                                    if (vh.story?.storyHash == boundStoryHash) {
                                        targetThumbView.requestLayout()
                                    }
                                }
                            }
                        }
                    }
                }
                StoryRowThumbnailVerticalMode.MATCH_ROW_HEIGHT -> {
                    params.addRule(RelativeLayout.ALIGN_PARENT_TOP)
                    params.addRule(RelativeLayout.ALIGN_PARENT_BOTTOM)
                    // With both ALIGN_PARENT_TOP and ALIGN_PARENT_BOTTOM, the
                    // RelativeLayout sizes the thumbnail to match the row height
                    // automatically — no doOnLayout callback or explicit pixel
                    // height needed.  This avoids the race where RecyclerView
                    // suppresses requestLayout() during its layout pass, which
                    // previously left fresh (non-recycled) views stuck at 1px.
                    thumbView?.setExpandedLayout(
                        layout.widthPx,
                        0,
                        layout.leftMarginPx,
                        layout.topMarginPx,
                        layout.rightMarginPx,
                        layout.bottomMarginPx,
                    )
                }
            }
        }

    }

    class FooterViewHolder(
        view: View,
    ) : RecyclerView.ViewHolder(view) {
        val innerView: FrameLayout = view.findViewById(R.id.footer_view_inner)
    }

    override fun onViewRecycled(viewHolder: RecyclerView.ViewHolder) {
        cancelReturnHighlight(viewHolder)
        if (viewHolder is StoryViewHolder) {
            viewHolder.dismissStoryMenu()
            if (viewHolder.thumbLoader != null) viewHolder.thumbLoader?.cancel = true
            viewHolder.lastThumbView = null
            viewHolder.readStateAnimator.cancel()
            viewHolder.cancelRowSwipe()
        }
        if (viewHolder is ClusterRowViewHolder) {
            viewHolder.previewLoader?.cancel = true
            viewHolder.readStateAnimator.cancel()
        }
        if (viewHolder is FooterViewHolder) {
            viewHolder.innerView.removeAllViews()
        }
    }

    private fun bindClusterRow(
        vh: ClusterRowViewHolder,
        item: DisplayItem.ClusterRow,
    ) {
        val clusterStory = item.clusterStory
        vh.clusterStory = clusterStory
        vh.readStateAnimator.cancel()

        val theme = prefsRepo.getResolvedTheme(context)
        val palette = StoryClusterThemeStyle.palette(theme)
        val isComfortable = spacingStyle == SpacingStyle.COMFORTABLE
        val isRead = clusterStory.read
        val feed = feedUtils.getFeed(clusterStory.feedId)
        val rowHeight = UIUtils.dp2px(context, if (isComfortable) 42 else 36)
        val verticalInset = 0

        vh.root.setBackgroundColor(palette.listBackgroundColor)
        vh.root.layoutParams =
            vh.root.layoutParams.apply {
                height = rowHeight
            }
        vh.card.background =
            StoryClusterThemeStyle.roundedBackground(
                palette.listCardColor,
                UIUtils.dp2px(context, if (isComfortable) 8 else 6).toFloat(),
            )
        (vh.card.layoutParams as? ViewGroup.MarginLayoutParams)?.let { params ->
            params.topMargin = verticalInset
            params.bottomMargin = verticalInset
            vh.card.layoutParams = params
        }
        vh.outerBar.setBackgroundColor(UIUtils.decodeColourValue(feed?.faviconColor, Color.GRAY))
        vh.innerBar.setBackgroundColor(UIUtils.decodeColourValue(feed?.faviconFade, Color.LTGRAY))

        vh.sentiment.setImageResource(StoryClusterDisplayDecision.indicatorDrawableRes(clusterStory.score))
        val sentimentSize = if (clusterStory.score == 0) 10 else 12
        vh.sentiment.layoutParams =
            vh.sentiment.layoutParams.apply {
                width = UIUtils.dp2px(context, sentimentSize)
                height = UIUtils.dp2px(context, sentimentSize)
            }

        vh.title.text = titleCache.get(clusterStory.title)
        vh.date.text = StoryUtils.formatRelativeShortDate(clusterStory.timestamp)
        vh.title.textSize = textSize * DEFAULT_TEXT_SIZE_STORY_SNIP
        vh.date.textSize = textSize * 10f
        StoryClusterBadgeViewBinder.bind(vh.badge, context, clusterStory.clusterTier, palette, false)

        bindFeedIcon(feed, vh.feedIcon, 16)
        bindClusterPreview(vh, clusterStory.thumbnailUrl ?: clusterThumbnailUrl(clusterStory.storyHash), isRead)

        vh.title.alpha = 1.0f
        vh.date.alpha = 1.0f
        bindClusterReadState(vh, clusterStory, animated = false)
    }

    private fun bindClusterReadState(vh: ClusterRowViewHolder, story: Story.ClusterStory, animated: Boolean) {
        val palette = StoryClusterThemeStyle.palette(prefsRepo.getResolvedTheme(context))
        val isRead = story.read
        vh.readStateAnimator.update(
            textColors = listOf(
                vh.title to if (isRead) palette.readTitleColor else palette.titleColor,
                vh.date to if (isRead) palette.readMetaColor else palette.metaColor,
            ),
            imageAlphas = listOf(
                vh.sentiment to if (isRead) CLUSTER_READ_SENTIMENT_ALPHA_B255 else 255,
                vh.feedIcon to if (isRead) CLUSTER_READ_FEED_ICON_ALPHA_B255 else 255,
                vh.preview to if (isRead) CLUSTER_READ_PREVIEW_ALPHA_B255 else 255,
            ),
            viewAlphas = listOf(
                vh.outerBar to if (isRead) CLUSTER_READ_BAR_ALPHA else 1f,
                vh.innerBar to if (isRead) CLUSTER_READ_BAR_ALPHA else 1f,
                vh.badge to if (isRead) 0.4f else 1f,
            ),
            animated = animated,
        )
    }

    private fun bindClusterPreview(
        vh: ClusterRowViewHolder,
        thumbnailUrl: String?,
        isRead: Boolean,
    ) {
        vh.previewLoader?.cancel = true
        if (thumbnailUrl.isNullOrBlank()) {
            updateClusterEndAnchors(vh.title, vh.badge, hasPreview = false, previewId = vh.preview.id, dateId = vh.date.id)
            vh.preview.visibility = View.GONE
            vh.preview.setImageDrawable(null)
            vh.previewLoader = null
            return
        }

        updateClusterEndAnchors(vh.title, vh.badge, hasPreview = true, previewId = vh.preview.id, dateId = vh.date.id)
        vh.preview.visibility = View.VISIBLE
        vh.preview.imageAlpha = if (isRead) CLUSTER_READ_PREVIEW_ALPHA_B255 else 255
        vh.preview.setImageDrawable(null)
        vh.previewLoader =
            thumbnailLoader.displayImage(
                thumbnailUrl,
                vh.preview,
                UIUtils.dp2px(context, 48),
                true,
            )
    }

    private fun updateClusterEndAnchors(
        titleView: TextView,
        badgeView: TextView,
        hasPreview: Boolean,
        previewId: Int,
        dateId: Int,
    ) {
        val badgeAnchorId = StoryClusterBadgeViewBinder.endAnchorId(hasPreview, previewId, dateId)
        val badgeParams = badgeView.layoutParams as RelativeLayout.LayoutParams
        badgeParams.addRule(RelativeLayout.START_OF, badgeAnchorId)
        badgeView.layoutParams = badgeParams

        val titleParams = titleView.layoutParams as RelativeLayout.LayoutParams
        titleParams.addRule(RelativeLayout.START_OF, badgeView.id)
        titleView.layoutParams = titleParams
    }

    private fun clusterThumbnailUrl(storyHash: String?): String? {
        if (storyHash.isNullOrBlank()) return null
        if (clusterThumbnailUrls.containsKey(storyHash)) {
            return clusterThumbnailUrls[storyHash]
        }

        return feedUtils.getStoryThumbnailUrl(storyHash).also { clusterThumbnailUrls[storyHash] = it }
    }

    private fun bindFeedIcon(
        feed: com.newsblur.domain.Feed?,
        target: ImageView,
        sizeDp: Int,
    ) {
        if (feed == null) {
            target.visibility = View.GONE
            return
        }

        val customFeedIcon: CustomIcon? = BlurDatabaseHelper.getFeedIcon(feed.feedId)
        if (customFeedIcon != null) {
            val iconSize = UIUtils.dp2px(context, sizeDp)
            val iconBitmap = CustomIconRenderer.renderIcon(context, customFeedIcon, iconSize)
            if (iconBitmap != null) {
                target.setImageBitmap(iconBitmap)
            } else {
                iconLoader.displayImage(feed.faviconUrl, target)
            }
        } else {
            iconLoader.displayImage(feed.faviconUrl, target)
        }
        target.visibility = View.VISIBLE
    }

    private fun subscribedFeedIds(): Set<String> {
        val cached = activeFeedIds
        if (cached != null) {
            return cached
        }

        return feedUtils.getActiveFeedIds().also { activeFeedIds = it }
    }

    private fun isArchiveUser(): Boolean = prefsRepo.getIsArchive() || prefsRepo.getIsPro()

    private fun visibleDisplayItemCount(): Int {
        if (fs == null || !UIUtils.needsSubscriptionAccess(fs, prefsRepo)) {
            return displayItems.size
        }

        val visibleStories = min(3.0, stories.size.toDouble()).toInt()
        if (visibleStories <= 0) {
            return 0
        }

        var seenStories = 0
        displayItems.forEachIndexed { index, item ->
            if (item is DisplayItem.StoryRow) {
                seenStories++
                if (seenStories == visibleStories) {
                    var end = index + 1
                    while (end < displayItems.size && displayItems[end] is DisplayItem.ClusterRow) {
                        end++
                    }
                    return end
                }
            }
        }

        return displayItems.size
    }

    private fun rebuildStoryDisplayPositions() {
        storyDisplayPositions.clear()
        displayItems.forEachIndexed { displayIndex, item ->
            if (item is DisplayItem.StoryRow) {
                storyDisplayPositions.add(displayIndex)
            }
        }
    }

    private fun rebuildDisplayItemsFromCurrentStories() {
        activeFeedIds = null
        displayItems.clear()
        displayItems.addAll(buildDisplayItems(stories))
        rebuildStoryDisplayPositions()
    }

    fun notifyAllItemsChanged() {
        // StoryViewAdapter.kt must not apply a diff calculated against the row shape this replaces.
        // Keep the latest pending data so an initial layout/preference change cannot drop its first batch.
        val pending = latestSubmission
        invalidateStoryDiffs()
        rebuildDisplayItemsFromCurrentStories()
        notifyDataSetChanged()
        pending?.let {
            submitStories(it.stories, it.loadId, it.grid, null, it.skipBackfill, it.onCommitted)
        }
    }

    private fun backgroundResourceFor(story: Story): Int {
        if (!story.isBriefingSummary) {
            return defaultBackgroundResource()
        }

        return when (prefsRepo.getResolvedTheme(context)) {
            ThemeValue.SEPIA -> R.drawable.sepia_daily_briefing_selector_story_background
            ThemeValue.DARK -> R.drawable.dark_daily_briefing_selector_story_background
            ThemeValue.BLACK -> R.drawable.black_daily_briefing_selector_story_background
            else -> R.drawable.daily_briefing_selector_story_background
        }
    }

    private fun defaultBackgroundResource(): Int =
        when (prefsRepo.getResolvedTheme(context)) {
            ThemeValue.SEPIA -> R.drawable.sepia_selector_story_background
            ThemeValue.DARK -> R.drawable.dark_selector_story_background
            ThemeValue.BLACK -> R.drawable.black_selector_story_background
            else -> R.drawable.selector_story_background
        }

    interface OnStoryClickListener {
        fun onStoryClicked(
            feedSet: FeedSet?,
            storyHash: String?,
        )
    }

    internal sealed interface DisplayItem {
        val stableId: Long
        val read: Boolean

        fun contentMatches(other: DisplayItem): Boolean = read == other.read && presentationMatches(other)
        fun presentationMatches(other: DisplayItem): Boolean

        data class StoryRow(
            val story: Story,
            val storyIndex: Int,
        ) : DisplayItem {
            override val stableId: Long = story.storyHash.hashCode().toLong()
            override val read = story.read
            private val content = StoryRowContent(story)

            override fun presentationMatches(other: DisplayItem): Boolean =
                other is StoryRow && content == other.content
        }

        data class ClusterRow(
            val clusterStory: Story.ClusterStory,
            val parentStoryIndex: Int,
            val parentStoryHash: String,
        ) : DisplayItem {
            override val stableId: Long = "$parentStoryHash:${clusterStory.storyHash}".hashCode().toLong()
            override val read = clusterStory.read
            private val content = ClusterRowContent(clusterStory)

            override fun presentationMatches(other: DisplayItem): Boolean =
                other is ClusterRow && content == other.content
        }
    }

    private object ReadStatePayload

    companion object {
        const val VIEW_TYPE_STORY_TILE: Int = 1
        const val VIEW_TYPE_STORY_ROW: Int = 2
        const val VIEW_TYPE_FOOTER: Int = 3
        const val VIEW_TYPE_CLUSTER_ROW: Int = 4

        private const val DEFAULT_TEXT_SIZE_STORY_FEED_TITLE = 13f
        private const val DEFAULT_TEXT_SIZE_STORY_TITLE = 14f
        private const val DEFAULT_TEXT_SIZE_STORY_DATE_OR_AUTHOR = 12f
        private const val DEFAULT_TEXT_SIZE_STORY_SNIP = 13f

        private const val READ_STORY_ALPHA = 0.35f
        private const val READ_STORY_ALPHA_B255 = (255f * READ_STORY_ALPHA).toInt()
        private const val CLUSTER_READ_BAR_ALPHA = 0.15f
        private const val CLUSTER_READ_PREVIEW_ALPHA_B255 = (255f * 0.55f).toInt()
        private const val CLUSTER_READ_SENTIMENT_ALPHA_B255 = (255f * 0.15f).toInt()
        private const val CLUSTER_READ_FEED_ICON_ALPHA_B255 = (255f * 0.4f).toInt()
    }
}
