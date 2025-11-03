package com.newsblur.database

import android.database.Cursor
import android.graphics.Color
import android.os.Parcelable
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
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.RelativeLayout
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.RecyclerView
import com.newsblur.R
import com.newsblur.activity.FeedItemsList
import com.newsblur.activity.NbActivity
import com.newsblur.domain.Story
import com.newsblur.domain.UserDetails
import com.newsblur.fragment.ItemSetFragment
import com.newsblur.fragment.StoryIntelTrainerFragment
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.FeedSet
import com.newsblur.util.FeedUtils
import com.newsblur.util.GestureAction
import com.newsblur.util.ImageLoader
import com.newsblur.util.ImageLoader.PhotoToLoad
import com.newsblur.util.Log
import com.newsblur.util.SpacingStyle
import com.newsblur.util.StoryContentPreviewStyle
import com.newsblur.util.StoryListStyle
import com.newsblur.util.StoryOrder
import com.newsblur.util.StoryUtil.getNewestStoryTimestamp
import com.newsblur.util.StoryUtil.getOldestStoryTimestamp
import com.newsblur.util.StoryUtil.getStoryHashes
import com.newsblur.util.StoryUtils
import com.newsblur.util.ThumbnailStyle
import com.newsblur.util.UIUtils
import com.newsblur.view.StoryThumbnailView
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.min

/**
 * Story list adapter, RecyclerView style.
 */
class StoryViewAdapter(
    private val context: NbActivity,
    private val fragment: ItemSetFragment,
    fs: FeedSet,
    listStyle: StoryListStyle,
    iconLoader: ImageLoader,
    thumbnailLoader: ImageLoader,
    feedUtils: FeedUtils,
    prefsRepo: PrefsRepo,
    listener: OnStoryClickListener,
) : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
    private val footerViews = mutableListOf<View>()

    // the cursor from which we pull story objects. should not be used except by the thaw/diff worker
    private var cursor: Cursor? = null

    // the live list of stories being used by the adapter
    private val stories = mutableListOf<Story>()

    private var oldScrollState: Parcelable? = null

    private val iconLoader: ImageLoader
    private val thumbnailLoader: ImageLoader
    private val feedUtils: FeedUtils
    private val executorService: ExecutorService
    private val listener: OnStoryClickListener
    private var fs: FeedSet?
    private var listStyle: StoryListStyle
    private var ignoreReadStatus = false
    private var ignoreIntel = false
    private var singleFeed = false
    private var textSize: Float
    private val user: UserDetails
    private var thumbnailStyle: ThumbnailStyle
    private var spacingStyle: SpacingStyle
    private val storyOrder: StoryOrder
    private val prefsRepo: PrefsRepo

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
        user = prefsRepo.getUserDetails()
        thumbnailStyle = prefsRepo.getThumbnailStyle()
        spacingStyle = prefsRepo.getSpacingStyle()
        storyOrder = prefsRepo.getStoryOrder(fs)

        executorService = Executors.newFixedThreadPool(1)

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
        get() =
            if (fs != null && UIUtils.needsSubscriptionAccess(fs, prefsRepo)) {
                min(3.0, stories.size.toDouble()).toInt()
            } else {
                stories.size
            }

    val rawStoryCount: Int
        /**
         * get the number of stories we very likely have, even if they haven't
         * been thawed yet, for callers that absolutely must know the size
         * of our dataset (such as for calculating when to fetch more stories)
         */
        get() {
            if (cursor == null) return 0
            if (cursor!!.isClosed) return 0
            var count = 0
            try {
                count = cursor!!.count
            } catch (e: Exception) {
                // rather than worry about sync locking for cursor changes, just fail. a
                // closing cursor may as well not be loaded.
            }
            return count
        }

    override fun getItemViewType(position: Int): Int {
        if (position >= storyCount) return VIEW_TYPE_FOOTER
        return if (listStyle == StoryListStyle.LIST) {
            VIEW_TYPE_STORY_ROW
        } else {
            VIEW_TYPE_STORY_TILE
        }
    }

    override fun getItemId(position: Int): Long {
        if (position >= storyCount) {
            return (footerViews[position - storyCount].hashCode().toLong())
        }

        if (position >= stories.size || position < 0) return 0
        return stories[position].storyHash.hashCode().toLong()
    }

    fun swapCursor(
        c: Cursor?,
        rv: RecyclerView,
        oldScrollState: Parcelable?,
        skipBackFillingStories: Boolean,
    ) {
        // cache the identity of the most recent cursor so async batches can check to
        // see if they are stale
        cursor = c
        // if the caller wants to restore a scroll state, hold onto it for when we update
        // the dataset and use that state at the right moment
        if (oldScrollState != null) {
            this.oldScrollState = oldScrollState
        }
        // process the cursor into objects and update the View async
        val r = Runnable { thawDiffUpdate(c, rv, skipBackFillingStories) }
        executorService.submit(r)
    }

    /**
     * Attempt to thaw a new set of stories from the cursor most recently
     * seen when the that cycle started.
     */
    private fun thawDiffUpdate(
        c: Cursor?,
        rv: RecyclerView,
        skipBackFillingStories: Boolean,
    ) {
        if (c !== cursor) return

        // thawed stories
        val newStories: MutableList<Story>
        var indexOfLastUnread = -1
        // attempt to thaw as gracefully as possible despite the fact that the loader
        // framework could close our cursor at any moment.  if this happens, it is fine,
        // as a new one will be provided and another cycle will start.  just return.
        try {
            if (c == null) {
                newStories = ArrayList()
            } else {
                if (c.isClosed) return
                newStories = ArrayList(c.count)
                c.moveToPosition(-1)

                // The 'skipBackFillingStories' flag is used to ensure that when the adapter resumes,
                // it omits any new stories that would disrupt the current order and cause the list to
                // unexpectedly jump, thereby preserving the scroll position. This flag specifically helps
                // manage the insertion of new stories that have been backfilled according to their timestamps.
                val currentStoryHashes = if (skipBackFillingStories) getStoryHashes(stories) else emptySet()
                val storyTimestampThreshold: Long? =
                    if (skipBackFillingStories && storyOrder == StoryOrder.NEWEST) {
                        getOldestStoryTimestamp(stories)
                    } else if (skipBackFillingStories && storyOrder == StoryOrder.OLDEST) {
                        getNewestStoryTimestamp(stories)
                    } else {
                        null
                    }

                while (c.moveToNext()) {
                    if (c.isClosed) return
                    val s = Story.fromCursor(c)
                    if (skipBackFillingStories && !currentStoryHashes.contains(s.storyHash)) {
                        if (storyOrder == StoryOrder.NEWEST && storyTimestampThreshold != null && s.timestamp >= storyTimestampThreshold) {
                            continue
                        } else if (storyOrder == StoryOrder.OLDEST &&
                            storyTimestampThreshold != null &&
                            s.timestamp <= storyTimestampThreshold
                        ) {
                            continue
                        }
                    }

                    s.bindExternValues(c)
                    newStories.add(s)
                    if (!s.read) indexOfLastUnread = c.position
                }
            }
        } catch (e: Exception) {
            Log.e(this, "error thawing story list: " + e.message, e)
            return
        }

        // generate the RecyclerView diff
        val diff = DiffUtil.calculateDiff(StoryListDiffer(newStories), false)

        if (c !== cursor) return

        fragment.storyThawCompleted(indexOfLastUnread)

        rv.post(
            Runnable {
                if (c !== cursor) return@Runnable
                // many versions of RecyclerView like to auto-scroll to inserted elements which is
                // not at all what we want.  the current scroll position is one of the things frozen
                // in instance state, so keep it and re-apply after deltas to preserve position
                val scrollState = rv.layoutManager!!.onSaveInstanceState()
                synchronized(this@StoryViewAdapter) {
                    stories.clear()
                    stories.addAll(newStories)
                    diff.dispatchUpdatesTo(this@StoryViewAdapter)
                    // the one exception to restoring state is if we were passed an old state to restore
                    // along with the cursor
                    if (oldScrollState != null) {
                        rv.layoutManager!!.onRestoreInstanceState(oldScrollState)
                        oldScrollState = null
                    } else {
                        rv.layoutManager!!.onRestoreInstanceState(scrollState)
                    }
                }
            },
        )
    }

    private inner class StoryListDiffer(
        private val newStories: List<Story>,
    ) : DiffUtil.Callback() {
        override fun areContentsTheSame(
            oldItemPosition: Int,
            newItemPosition: Int,
        ): Boolean = newStories[newItemPosition].isChanged(stories[oldItemPosition])

        override fun areItemsTheSame(
            oldItemPosition: Int,
            newItemPosition: Int,
        ): Boolean = newStories[newItemPosition].storyHash == stories[oldItemPosition].storyHash

        override fun getNewListSize(): Int = newStories.size

        override fun getOldListSize(): Int = stories.size
    }

    @Synchronized
    fun getStory(position: Int): Story? =
        if (position >= stories.size || position < 0) {
            null
        } else {
            stories[position]
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
        } else if (viewType == VIEW_TYPE_STORY_ROW) {
            val v = LayoutInflater.from(viewGroup.context).inflate(R.layout.view_story_row, viewGroup, false)
            v.setLayerType(View.LAYER_TYPE_HARDWARE, null)
            return StoryRowViewHolder(v)
        } else {
            val v = LayoutInflater.from(viewGroup.context).inflate(R.layout.view_footer_tile, viewGroup, false)
            return FooterViewHolder(v)
        }
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
                val fs = FeedSet.singleFeed(story!!.feedId)
                FeedItemsList.startActivity(
                    context,
                    fs,
                    feedUtils.getFeed(story!!.feedId),
                    null,
                    null,
                )
                return true
            } else {
                return false
            }
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
                GestureAction.GEST_ACTION_MARKREAD -> feedUtils.markStoryAsRead(story!!, context)
                GestureAction.GEST_ACTION_MARKUNREAD -> feedUtils.markStoryUnread(story!!, context)
                GestureAction.GEST_ACTION_SAVE -> feedUtils.setStorySaved(story!!, true, context, emptyList(), emptyList())
                GestureAction.GEST_ACTION_UNSAVE -> feedUtils.setStorySaved(story!!, false, context, emptyList(), emptyList())
                GestureAction.GEST_ACTION_STATISTICS -> feedUtils.openStatistics(context, prefsRepo, story!!.feedId)
                GestureAction.GEST_ACTION_NONE -> {}
                else -> {}
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

    override fun onBindViewHolder(
        viewHolder: RecyclerView.ViewHolder,
        position: Int,
    ) {
        if (viewHolder is StoryViewHolder) {
            if (position >= stories.size || position < 0) return

            val story = stories[position]
            viewHolder.story = story

            bindCommon(viewHolder, story)

            if (viewHolder is StoryRowViewHolder) {
                bindRow(viewHolder, story)
            } else {
                val vhTile = viewHolder as StoryTileViewHolder
                bindTile(vhTile, story)
            }
        } else {
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
        }
    }

    /**
     * Bind view elements that are common to tiles and rows.
     */
    private fun bindCommon(
        vh: StoryViewHolder,
        story: Story,
    ) {
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
            iconLoader.displayImage(story.extern_faviconUrl, vh.feedIconView)
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
            if (TextUtils.equals(userId, user.id)) {
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
        if (this.ignoreReadStatus || (!story.read)) {
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
            vh.feedTitleView.alpha = READ_STORY_ALPHA
            vh.storyTitleView.alpha = READ_STORY_ALPHA
            vh.storyDate.alpha = READ_STORY_ALPHA
        }
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

        val contentRightPadding = spacingStyle.getStoryContentRightPadding(context, thumbnailStyle)
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
                vh.thumbLoader = thumbnailLoader.displayImage(story.thumbnailUrl, vh.thumbViewRight, thumbSizeGuess, true)
                vh.thumbViewLeft.visibility = View.GONE
                val hideThumbnail = TextUtils.isEmpty(story.thumbnailUrl) && storyContentPreviewStyle == StoryContentPreviewStyle.NONE
                vh.thumbViewRight.visibility = if (hideThumbnail) View.GONE else View.VISIBLE
            }
            vh.lastThumbUrl = story.thumbnailUrl
        } else if (vh.thumbViewRight != null && vh.thumbViewLeft != null) {
            // if in row mode and thumbnail is disabled or missing, don't just hide but collapse
            vh.thumbViewRight.visibility = View.GONE
            vh.thumbViewLeft.visibility = View.GONE
        }

        var sizeRes = R.dimen.thumbnails_size
        if (thumbnailStyle.isSmall()) {
            sizeRes = R.dimen.thumbnails_small_size
        }
        val sizeDp = context.resources.getDimensionPixelSize(sizeRes)

        var params: RelativeLayout.LayoutParams? = null
        if (thumbnailStyle.isLeft() && vh.thumbViewLeft != null) {
            vh.thumbViewLeft.setThumbnailStyle(thumbnailStyle)
            params = vh.thumbViewLeft.layoutParams as RelativeLayout.LayoutParams
        } else if (thumbnailStyle.isRight() && vh.thumbViewRight != null) {
            vh.thumbViewRight.setThumbnailStyle(thumbnailStyle)
            params = vh.thumbViewRight.layoutParams as RelativeLayout.LayoutParams
        }
        if (params != null && params.width != sizeDp) {
            params.width = sizeDp
        }
        if (params != null && thumbnailStyle.isSmall()) {
            val verticalMargin = if (singleFeed) verticalContainerMargin + UIUtils.dp2px(context, 2) else verticalContainerMargin
            val leftMargin = if (thumbnailStyle.isLeft()) UIUtils.dp2px(context, 8) else 0
            val rightMargin = if (thumbnailStyle.isRight()) UIUtils.dp2px(context, 8) else 0
            params.setMargins(leftMargin, verticalMargin, rightMargin, verticalMargin)
            params.addRule(RelativeLayout.ALIGN_BOTTOM, vh.storySnippet.id)
        } else if (params != null) {
            params.setMargins(0, 0, 0, 0)
            params.removeRule(RelativeLayout.ALIGN_BOTTOM)
            params.height = sizeDp
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
        if (viewHolder is FooterViewHolder) {
            viewHolder.innerView.removeAllViews()
        }
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
    }

    fun notifyAllItemsChanged() {
        notifyItemRangeChanged(0, itemCount)
    }

    interface OnStoryClickListener {
        fun onStoryClicked(
            feedSet: FeedSet?,
            storyHash: String?,
        )
    }

    companion object {
        const val VIEW_TYPE_STORY_TILE: Int = 1
        const val VIEW_TYPE_STORY_ROW: Int = 2
        const val VIEW_TYPE_FOOTER: Int = 3

        private const val DEFAULT_TEXT_SIZE_STORY_FEED_TITLE = 13f
        private const val DEFAULT_TEXT_SIZE_STORY_TITLE = 14f
        private const val DEFAULT_TEXT_SIZE_STORY_DATE_OR_AUTHOR = 12f
        private const val DEFAULT_TEXT_SIZE_STORY_SNIP = 13f

        private const val READ_STORY_ALPHA = 0.35f
        private const val READ_STORY_ALPHA_B255 = (255f * READ_STORY_ALPHA).toInt()
    }
}
