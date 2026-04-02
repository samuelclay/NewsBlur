@file:OptIn(ExperimentalCoroutinesApi::class)

package com.newsblur.database

import android.graphics.Color
import android.os.Parcelable
import android.os.SystemClock
import android.text.TextUtils
import android.view.ContextMenu
import android.view.ContextMenu.ContextMenuInfo
import android.view.GestureDetector
import android.view.GestureDetector.SimpleOnGestureListener
import android.view.LayoutInflater
import android.view.MenuInflater
import android.view.MenuItem
import android.view.MotionEvent
import android.view.View
import android.view.View.OnCreateContextMenuListener
import android.view.View.OnTouchListener
import android.view.ViewGroup
import android.view.ViewConfiguration
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.RelativeLayout
import android.widget.TextView
import androidx.core.view.doOnLayout
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.R
import com.newsblur.activity.FeedItemsList
import com.newsblur.activity.ItemsList
import com.newsblur.activity.NbActivity
import com.newsblur.design.StoryRowPalette
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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
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

    @Volatile
    private var lastLoadId: Long = -1L

    private val adapterScope = CoroutineScope(SupervisorJob() + Dispatchers.Default.limitedParallelism(1))
    private var diffJob: Job? = null

    init {
        this.fs = fs
        this.listStyle = listStyle
        this.iconLoader = iconLoader
        this.thumbnailLoader = thumbnailLoader
        this.feedUtils = feedUtils
        this.listener = listener
        this.prefsRepo = prefsRepo

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
        this.fs = fs
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

    fun submitStories(
        stories: List<Story>,
        loadId: Long,
        rv: RecyclerView,
        oldScrollState: Parcelable?,
        skipBackFillingStories: Boolean,
    ) {
        lastLoadId = loadId
        activeFeedIds = null
        clusterThumbnailUrls.clear()

        oldScrollState?.let { this.oldScrollState = it }

        diffJob?.cancel()
        diffJob =
            adapterScope.launch {
                val filtered = applySkipBackfill(incoming = stories, skip = skipBackFillingStories)
                val newDisplayItems = buildDisplayItems(filtered)

                val diff =
                    try {
                        DiffUtil.calculateDiff(DisplayItemDiffer(newDisplayItems), false)
                    } catch (e: Exception) {
                        Log.e(this@StoryViewAdapter, "error diffing: ${e.message}", e)
                        return@launch
                    }

                if (loadId != lastLoadId) return@launch

                withContext(Dispatchers.Main) {
                    if (loadId != lastLoadId) return@withContext
                    val scrollState = rv.layoutManager?.onSaveInstanceState()
                    synchronized(this@StoryViewAdapter) {
                        this@StoryViewAdapter.stories.clear()
                        this@StoryViewAdapter.stories.addAll(filtered)
                        this@StoryViewAdapter.displayItems.clear()
                        this@StoryViewAdapter.displayItems.addAll(newDisplayItems)
                        rebuildStoryDisplayPositions()
                        diff.dispatchUpdatesTo(this@StoryViewAdapter)
                        val lm = rv.layoutManager
                        if (lm != null) {
                            val pendingHash = pendingScrollStoryHash
                            if (pendingHash != null) {
                                pendingScrollStoryHash = null
                                val pos = getDisplayPositionForStoryHash(pendingHash)
                                if (pos >= 0) {
                                    lm.onRestoreInstanceState(scrollState)
                                    val llm = lm as? LinearLayoutManager
                                    val first = llm?.findFirstVisibleItemPosition() ?: -1
                                    val last = llm?.findLastVisibleItemPosition() ?: -1
                                    if (ReturnedStoryScrollDecider.shouldScrollToReturnedStory(pos, first, last)) {
                                        llm?.scrollToPosition(pos)
                                    }
                                } else {
                                    lm.onRestoreInstanceState(scrollState)
                                }
                            } else if (oldScrollState != null) {
                                lm.onRestoreInstanceState(oldScrollState)
                                this@StoryViewAdapter.oldScrollState = null
                            } else {
                                lm.onRestoreInstanceState(scrollState)
                            }
                        }
                    }
                }
            }
    }

    private fun buildDisplayItems(stories: List<Story>): List<DisplayItem> {
        val showClusterRows = listStyle == StoryListStyle.LIST && StoryClusterDisplayDecision.isStoryClusteringEnabled(prefsRepo)
        val subscribedFeedIds = if (showClusterRows) subscribedFeedIds() else emptySet()
        val isArchiveUser = isArchiveUser()

        return buildList {
            stories.forEachIndexed { storyIndex, story ->
                add(DisplayItem.StoryRow(story, storyIndex))

                if (!showClusterRows || story.isBriefingSummary) return@forEachIndexed

                StoryClusterDisplayDecision.visibleClusterStories(
                    clusterStories = story.clusterStories,
                    subscribedFeedIds = subscribedFeedIds,
                    isPremiumArchive = isArchiveUser,
                ).forEach { clusterStory ->
                    add(DisplayItem.ClusterRow(clusterStory, storyIndex, story.storyHash))
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

    private inner class DisplayItemDiffer(
        private val newDisplayItems: List<DisplayItem>,
    ) : DiffUtil.Callback() {
        override fun areContentsTheSame(
            oldItemPosition: Int,
            newItemPosition: Int,
        ): Boolean = newDisplayItems[newItemPosition].contentMatches(displayItems[oldItemPosition])

        override fun areItemsTheSame(
            oldItemPosition: Int,
            newItemPosition: Int,
        ): Boolean =
            newDisplayItems[newItemPosition].stableId == displayItems[oldItemPosition].stableId &&
                newDisplayItems[newItemPosition]::class == displayItems[oldItemPosition]::class

        override fun getNewListSize(): Int = newDisplayItems.size

        override fun getOldListSize(): Int = displayItems.size
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

    fun setTextSize(textSize: Float) {
        this.textSize = textSize
    }

    override fun onCreateViewHolder(
        viewGroup: ViewGroup,
        viewType: Int,
    ): RecyclerView.ViewHolder {
        // NB: the non-temporary calls to setLayerType() dramatically speed up list movement, but
        // are only safe because we perform fairly advanced delta updates. if any changes to invalidation
        // logic are made, check the list with hardare layer profiling to ensure we aren't over-invalidating
        if (viewType == VIEW_TYPE_STORY_TILE) {
            val v = LayoutInflater.from(viewGroup.context).inflate(R.layout.view_story_tile, viewGroup, false)
            v.setLayerType(View.LAYER_TYPE_HARDWARE, null)
            return StoryTileViewHolder(v)
        } else if (viewType == VIEW_TYPE_CLUSTER_ROW) {
            val v = LayoutInflater.from(viewGroup.context).inflate(R.layout.view_story_cluster_row, viewGroup, false)
            return ClusterRowViewHolder(v)
        } else if (viewType == VIEW_TYPE_STORY_ROW) {
            val v = LayoutInflater.from(viewGroup.context).inflate(R.layout.view_story_row, viewGroup, false)
            v.setLayerType(View.LAYER_TYPE_HARDWARE, null)
            return StoryRowViewHolder(v)
        } else {
            val v = LayoutInflater.from(viewGroup.context).inflate(R.layout.view_footer_tile, viewGroup, false)
            return FooterViewHolder(v)
        }
    }

    override fun onDetachedFromRecyclerView(recyclerView: RecyclerView) {
        super.onDetachedFromRecyclerView(recyclerView)
        diffJob?.cancel()
        adapterScope.cancel()
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
        var thumbLoader: PhotoToLoad? = null
        var lastThumbUrl: String? = null
        var gestureR2L: Boolean = false
        var gestureL2R: Boolean = false
        var gestureDebounce: Boolean = false

        private val gestureDetector = GestureDetector(context, StoryViewGestureDetector(this))

        init {
            view.setOnClickListener(this)
            view.setOnCreateContextMenuListener(this)
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
            val now = SystemClock.elapsedRealtime()
            if (now - lastStoryOpenElapsedRealtime < ViewConfiguration.getDoubleTapTimeout().toLong()) return
            lastStoryOpenElapsedRealtime = now
            listener.onStoryClicked(fs, story?.storyHash)
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
            // detector looks for ongoing gestures and sets our flags
            val result = gestureDetector.onTouchEvent(event)
            // iff a gesture possibly completed, see if any were found
            if (event.actionMasked == MotionEvent.ACTION_UP) {
                flushGesture()
            } else if (event.actionMasked == MotionEvent.ACTION_CANCEL) {
                // RecyclerViews may take event ownership to detect scrolling and never send an ACTION_UP
                // to children.  valid gestures end in a CANCEL more often than not
                flushGesture()
            }
            return result
        }

        private fun flushGesture() {
            // by default, do nothing
            var action: GestureAction? = GestureAction.GEST_ACTION_NONE
            if (gestureL2R) {
                action = prefsRepo.getLeftToRightGestureAction()
                gestureL2R = false
            }
            if (gestureR2L) {
                action = prefsRepo.getRightToLeftGestureAction()
                gestureR2L = false
            }
            when (action) {
                GestureAction.GEST_ACTION_BACK -> (context as? ItemsList)?.completeInteractiveStoryListSwipe()
                GestureAction.GEST_ACTION_TOGGLE_READ -> toggleStoryReadState()
                GestureAction.GEST_ACTION_MARKREAD -> feedUtils.markStoryAsRead(story!!, context)
                GestureAction.GEST_ACTION_MARKUNREAD -> feedUtils.markStoryUnread(story!!, context)
                GestureAction.GEST_ACTION_SAVE -> feedUtils.setStorySaved(story!!, true, context, emptyList(), emptyList())
                GestureAction.GEST_ACTION_UNSAVE -> feedUtils.setStorySaved(story!!, false, context, emptyList(), emptyList())
                GestureAction.GEST_ACTION_STATISTICS -> feedUtils.openStatistics(context, prefsRepo, story!!.feedId)
                GestureAction.GEST_ACTION_NONE -> {}
                else -> {}
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
        val title: TextView = view.findViewById(R.id.story_cluster_row_title)
        val date: TextView = view.findViewById(R.id.story_cluster_row_date)

        var clusterStory: Story.ClusterStory? = null
        var previewLoader: PhotoToLoad? = null

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
                    listener.onStoryClicked(target.feedSet, target.storyHash)
                }

                is StoryClusterNavigationTarget.FeedListReading -> {
                    val feed = feedUtils.getFeed(feedId)
                    if (feed == null) {
                        listener.onStoryClicked(target.feedSet, target.storyHash)
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
    ) {
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
                storyHolder.story = story
                bindCommon(storyHolder, story)

                if (storyHolder is StoryRowViewHolder) {
                    bindRow(storyHolder, story)
                } else {
                    bindTile(storyHolder as StoryTileViewHolder, story)
                }
            }
            is DisplayItem.ClusterRow -> {
                bindClusterRow(viewHolder as ClusterRowViewHolder, item)
            }
        }
    }

    /**
     * Bind view elements that are common to tiles and rows.
     */
    private fun bindCommon(
        vh: StoryViewHolder,
        story: Story,
    ) {
        val isRead = !ignoreReadStatus && story.read
        val theme = prefsRepo.getResolvedTheme(context)

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

        vh.storyTitleView.text = UIUtils.fromHtml(story.title)
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
            vh.feedTitleView.setTextColor(StoryRowPalette.feedTitleArgb(theme, isRead))
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

        // dynamic spacing
        val verticalTitlePadding = spacingStyle.getStoryTitleVerticalPadding(context)
        val rightTitlePadding = spacingStyle.getStoryContentRightPadding(context, thumbnailStyle)
        vh.storyTitleView.setPadding(
            vh.storyTitleView.paddingLeft,
            verticalTitlePadding,
            rightTitlePadding,
            verticalTitlePadding,
        )

        // read/unread fading
        if (!isRead) {
            vh.leftBarOne.background.alpha = 255
            vh.leftBarTwo.background.alpha = 255
            vh.intelDot.imageAlpha = 255
            vh.thumbViewLeft?.let { it.imageAlpha = 255 }
            vh.thumbViewRight?.let { it.imageAlpha = 255 }
            vh.thumbTileView?.let { it.imageAlpha = 255 }
            vh.feedIconView.imageAlpha = 255
            vh.feedTitleView.alpha = 1.0f
            vh.storyTitleView.alpha = 1.0f
            vh.storyDate.alpha = 1.0f
        } else {
            vh.leftBarOne.background.alpha = READ_STORY_ALPHA_B255
            vh.leftBarTwo.background.alpha = READ_STORY_ALPHA_B255
            vh.intelDot.imageAlpha = READ_STORY_ALPHA_B255
            vh.thumbViewLeft?.let { it.imageAlpha = READ_STORY_ALPHA_B255 }
            vh.thumbViewRight?.let { it.imageAlpha = READ_STORY_ALPHA_B255 }
            vh.thumbTileView?.let { it.imageAlpha = READ_STORY_ALPHA_B255 }
            vh.feedIconView.imageAlpha = READ_STORY_ALPHA_B255
            vh.feedTitleView.alpha = 1.0f
            vh.storyTitleView.alpha = READ_STORY_ALPHA
            vh.storyDate.alpha = READ_STORY_ALPHA
        }
    }

    private fun bindTile(
        vh: StoryTileViewHolder,
        story: Story,
    ) {
        vh.thumbLoader?.cancel = true
        vh.thumbLoader = null

        // when first created, tiles' views tend to not yet have their dimensions calculated, but
        // upon being recycled they will often have a known size, which lets us give a max size to
        // the image loader, which in turn can massively optimise loading.  the image loader will
        // reject nonsene values

        if (!thumbnailStyle.isOff() && vh.thumbTileView != null) {
            // the view will display a stale, recycled thumb before the new one loads if the old is not cleared
            val thumbSizeGuess = vh.thumbTileView.measuredHeight
            vh.thumbTileView.setImageBitmap(null)
            vh.thumbLoader = thumbnailLoader.displayImage(story.thumbnailUrl, vh.thumbTileView, thumbSizeGuess, true)
            vh.lastThumbUrl = story.thumbnailUrl
        }
    }

    private fun bindRow(
        vh: StoryRowViewHolder,
        story: Story,
    ) {
        val storyContentPreviewStyle = prefsRepo.getStoryContentPreviewStyle()
        val showRightThumbnail = thumbnailStyle.isRight() && !TextUtils.isEmpty(story.thumbnailUrl)

        vh.thumbLoader?.cancel = true
        vh.thumbLoader = null

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
                vh.thumbViewLeft.setImageBitmap(null)
                vh.thumbLoader = thumbnailLoader.displayImage(story.thumbnailUrl, vh.thumbViewLeft, thumbSizeGuess, true)
                vh.thumbViewRight.visibility = View.GONE
                vh.thumbViewLeft.visibility = View.VISIBLE
            } else if (thumbnailStyle.isRight()) {
                val thumbSizeGuess = vh.thumbViewRight.measuredHeight
                vh.thumbViewRight.setImageBitmap(null)
                vh.thumbViewLeft.visibility = View.GONE
                if (showRightThumbnail) {
                    vh.thumbLoader = thumbnailLoader.displayImage(story.thumbnailUrl, vh.thumbViewRight, thumbSizeGuess, true)
                    vh.thumbViewRight.visibility = View.VISIBLE
                } else {
                    vh.thumbViewRight.visibility = View.GONE
                }
            }
            vh.lastThumbUrl = story.thumbnailUrl
        } else if (vh.thumbViewRight != null && vh.thumbViewLeft != null) {
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
                        // 1px sliver.  Fresh views (height 0) still start at 1 so the
                        // thumbnail does not influence the first row measurement.
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
                            layout.fixedHeightPx ?: 1
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
                        }
                    }
                }
                StoryRowThumbnailVerticalMode.MATCH_ROW_HEIGHT -> {
                    params.addRule(RelativeLayout.ALIGN_PARENT_TOP)
                    val targetThumbView = thumbView
                    if (targetThumbView != null) {
                        val boundStoryHash = story.storyHash
                        val boundThumbnailStyle = thumbnailStyle

                        // For recycled views, use the existing row height so the thumbnail
                        // doesn't flash at 1px.  For fresh views, start at 1 so the text
                        // content determines the initial row height.
                        val initialHeight = vh.itemView.height.coerceAtLeast(1)
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
                            targetThumbView.setExpandedLayout(
                                layout.widthPx,
                                itemView.height.coerceAtLeast(1),
                                layout.leftMarginPx,
                                layout.topMarginPx,
                                layout.rightMarginPx,
                                layout.bottomMarginPx,
                            )
                        }
                    }
                }
            }
        }

        if (this.ignoreReadStatus || !story.read) {
            vh.storyAuthor.alpha = 1.0f
            vh.storySnippet.alpha = 1.0f
        } else {
            vh.storyAuthor.alpha = READ_STORY_ALPHA
            vh.storySnippet.alpha = READ_STORY_ALPHA
        }
    }

    class FooterViewHolder(
        view: View,
    ) : RecyclerView.ViewHolder(view) {
        val innerView: FrameLayout = view.findViewById(R.id.footer_view_inner)
    }

    override fun onViewRecycled(viewHolder: RecyclerView.ViewHolder) {
        if (viewHolder is StoryViewHolder) {
            if (viewHolder.thumbLoader != null) viewHolder.thumbLoader?.cancel = true
        }
        if (viewHolder is ClusterRowViewHolder) {
            viewHolder.previewLoader?.cancel = true
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

        vh.title.text = UIUtils.fromHtml(clusterStory.title ?: "")
        vh.date.text = StoryUtils.formatRelativeShortDate(clusterStory.timestamp)
        vh.title.textSize = textSize * DEFAULT_TEXT_SIZE_STORY_SNIP
        vh.date.textSize = textSize * 10f
        vh.title.setTextColor(if (isRead) palette.readTitleColor else palette.titleColor)
        vh.date.setTextColor(if (isRead) palette.readMetaColor else palette.metaColor)

        bindFeedIcon(feed, vh.feedIcon, 16)
        bindClusterPreview(vh, clusterStory.thumbnailUrl ?: clusterThumbnailUrl(clusterStory.storyHash), isRead)

        vh.outerBar.alpha = if (isRead) CLUSTER_READ_BAR_ALPHA else 1.0f
        vh.innerBar.alpha = if (isRead) CLUSTER_READ_BAR_ALPHA else 1.0f
        vh.sentiment.imageAlpha = if (isRead) CLUSTER_READ_SENTIMENT_ALPHA_B255 else 255
        vh.feedIcon.imageAlpha = if (isRead) CLUSTER_READ_FEED_ICON_ALPHA_B255 else 255
        vh.title.alpha = 1.0f
        vh.date.alpha = 1.0f
    }

    private fun bindClusterPreview(
        vh: ClusterRowViewHolder,
        thumbnailUrl: String?,
        isRead: Boolean,
    ) {
        vh.previewLoader?.cancel = true
        if (thumbnailUrl.isNullOrBlank()) {
            updateClusterTitleEndAnchor(vh.title, vh.date.id)
            vh.preview.visibility = View.GONE
            vh.preview.setImageDrawable(null)
            vh.previewLoader = null
            return
        }

        updateClusterTitleEndAnchor(vh.title, vh.preview.id)
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

    private fun updateClusterTitleEndAnchor(
        titleView: TextView,
        anchorId: Int,
    ) {
        val params = titleView.layoutParams as RelativeLayout.LayoutParams
        params.addRule(RelativeLayout.START_OF, anchorId)
        titleView.layoutParams = params
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

    internal inner class StoryViewGestureDetector(
        private val vh: StoryViewHolder,
    ) : SimpleOnGestureListener() {
        override fun onScroll(
            e1: MotionEvent?,
            e2: MotionEvent,
            distanceX: Float,
            distanceY: Float,
        ): Boolean {
            val displayWidthPx = UIUtils.getDisplayWidthPx(context)
            val edgeWithNavGesturesPaddingPx = UIUtils.dp2px(context, 40).toFloat()
            val rightEdgeNavGesturePaddingPx = displayWidthPx - edgeWithNavGesturesPaddingPx
            if (e1 != null &&
                shouldHandleLeftToRightStoryGesture() &&
                e1.x > edgeWithNavGesturesPaddingPx &&
                // the gesture should not start too close to the left edge and
                e2.x - e1.x > 50f &&
                // move horizontally to the right and
                abs(distanceY.toDouble()) < 25f
            ) { // have minimal vertical travel, so we don't capture scrolling gestures
                vh.gestureL2R = true
                vh.gestureDebounce = true
                return true
            }
            if (e1 != null &&
                e1.x < rightEdgeNavGesturePaddingPx &&
                // the gesture should not start too close to the right edge and
                e1.x - e2.x > 50f &&
                // move horizontally to the left and
                abs(distanceY.toDouble()) < 25f
            ) { // have minimal vertical travel, so we don't capture scrolling gestures
                vh.gestureR2L = true
                vh.gestureDebounce = true
                return true
            }
            return false
        }

        private fun shouldHandleLeftToRightStoryGesture(): Boolean {
            if (context !is ItemsList) return true
            return prefsRepo.getLeftToRightGestureAction() != GestureAction.GEST_ACTION_BACK
        }
    }

    fun notifyAllItemsChanged() {
        rebuildDisplayItemsFromCurrentStories()
        notifyDataSetChanged()
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

    private sealed interface DisplayItem {
        val stableId: Long

        fun contentMatches(other: DisplayItem): Boolean

        data class StoryRow(
            val story: Story,
            val storyIndex: Int,
        ) : DisplayItem {
            override val stableId: Long = story.storyHash.hashCode().toLong()

            override fun contentMatches(other: DisplayItem): Boolean =
                other is StoryRow && story.isChanged(other.story)
        }

        data class ClusterRow(
            val clusterStory: Story.ClusterStory,
            val parentStoryIndex: Int,
            val parentStoryHash: String,
        ) : DisplayItem {
            override val stableId: Long = "$parentStoryHash:${clusterStory.storyHash}".hashCode().toLong()

            override fun contentMatches(other: DisplayItem): Boolean =
                other is ClusterRow && clusterStory == other.clusterStory
        }
    }

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
