package com.newsblur.activity

import android.content.Intent
import android.content.res.Configuration
import android.database.Cursor
import android.os.Bundle
import android.util.Log
import android.view.KeyEvent
import android.view.MenuItem
import android.view.View
import android.widget.Toast
import androidx.fragment.app.FragmentManager
import androidx.fragment.app.commit
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.viewpager.widget.ViewPager
import androidx.viewpager.widget.ViewPager.OnPageChangeListener
import com.google.android.material.progressindicator.CircularProgressIndicator
import com.newsblur.R
import com.newsblur.database.ReadingAdapter
import com.newsblur.databinding.ActivityReadingBinding
import com.newsblur.di.IconLoader
import com.newsblur.domain.Story
import com.newsblur.fragment.ReadingItemFragment
import com.newsblur.fragment.ReadingPagerFragment
import com.newsblur.service.NBSyncReceiver.Companion.UPDATE_REBUILD
import com.newsblur.service.NBSyncReceiver.Companion.UPDATE_STATUS
import com.newsblur.service.NBSyncReceiver.Companion.UPDATE_STORY
import com.newsblur.service.NBSyncService
import com.newsblur.util.*
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.view.ReadingScrollView.ScrollChangeListener
import com.newsblur.viewModel.StoriesViewModel
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.lang.Runnable
import javax.inject.Inject
import kotlin.math.abs

@AndroidEntryPoint
abstract class Reading : NbActivity(), OnPageChangeListener, ScrollChangeListener {

    @Inject
    lateinit var feedUtils: FeedUtils

    @Inject
    @IconLoader
    lateinit var iconLoader: ImageLoader

    @JvmField
    var fs: FeedSet? = null

    private var stories: Cursor? = null

    // Activities navigate to a particular story by hash.
    // We can find it once we have the cursor.
    private var storyHash: String? = null

    private var pager: ViewPager? = null
    private var readingAdapter: ReadingAdapter? = null
    private var stopLoading = false
    private var unreadSearchActive = false

    // mark story as read behavior
    private var markStoryReadJob: Job? = null
    private lateinit var markStoryReadBehavior: MarkStoryReadBehavior

    // unread count for the circular progress overlay. set to nonzero to activate the progress indicator overlay
    private var startingUnreadCount = 0
    private var overlayRangeTopPx = 0f
    private var overlayRangeBotPx = 0f
    private var lastVScrollPos = 0

    // enabling multi window mode from recent apps on the device
    // creates a different activity lifecycle compared to a device rotation
    // resulting in onPause being called when the app is actually on the screen.
    // calling onPause sets stopLoading as true and content wouldn't be loaded.
    // track the multi window mode config change and skip stopLoading in first onPause call.
    // refactor stopLoading mechanism as a cancellation signal tied to the view lifecycle.
    private var isMultiWindowModeHack = false

    private val pageHistory = mutableListOf<Story>()

    private lateinit var volumeKeyNavigation: VolumeKeyNavigation
    private lateinit var intelState: StateFilter
    private lateinit var binding: ActivityReadingBinding
    private lateinit var storiesViewModel: StoriesViewModel

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onCreate(savedInstanceBundle: Bundle?) {
        super.onCreate(savedInstanceBundle)
        storiesViewModel = ViewModelProvider(this).get(StoriesViewModel::class.java)
        binding = ActivityReadingBinding.inflate(layoutInflater)
        setContentView(binding.root)

        try {
            fs = intent.getSerializableExtra(EXTRA_FEEDSET) as FeedSet?
        } catch (re: RuntimeException) {
            // in the wild, the notification system likes to pass us an Intent that has missing or very stale
            // Serializable extras.
            com.newsblur.util.Log.e(this, "failed to unfreeze required extras", re)
            finish()
            return
        }

        if (fs == null) {
            com.newsblur.util.Log.w(this.javaClass.name, "reading view had no FeedSet")
            finish()
            return
        }

        if (savedInstanceBundle != null && savedInstanceBundle.containsKey(BUNDLE_STARTING_UNREAD)) {
            startingUnreadCount = savedInstanceBundle.getInt(BUNDLE_STARTING_UNREAD)
        }

        // Only use the storyHash the first time the activity is loaded. Ignore when
        // recreated due to rotation etc.
        storyHash = if (savedInstanceBundle == null) {
            intent.getStringExtra(EXTRA_STORY_HASH)
        } else {
            savedInstanceBundle.getString(EXTRA_STORY_HASH)
        }

        intelState = PrefsUtils.getStateFilter(this)
        volumeKeyNavigation = PrefsUtils.getVolumeKeyNavigation(this)
        markStoryReadBehavior = PrefsUtils.getMarkStoryReadBehavior(this)

        setupViews()
        setupListeners()
        setupObservers()
        getActiveStoriesCursor(true)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        if (storyHash != null) {
            outState.putString(EXTRA_STORY_HASH, storyHash)
        } else if (pager != null) {
            val currentItem = pager!!.currentItem
            val story = readingAdapter!!.getStory(currentItem)
            if (story != null) {
                outState.putString(EXTRA_STORY_HASH, story.storyHash)
            }
        }

        if (startingUnreadCount != 0) {
            outState.putInt(BUNDLE_STARTING_UNREAD, startingUnreadCount)
        }
    }

    override fun onResume() {
        super.onResume()
        if (NBSyncService.isHousekeepingRunning()) finish()
        // this view shows stories, it is not safe to perform cleanup
        stopLoading = false
        // this is not strictly necessary, since our first refresh with the fs will swap in
        // the correct session, but that can be delayed by sync backup, so we try here to
        // reduce UI lag, or in case somehow we got redisplayed in a zero-story state
        feedUtils.prepareReadingSession(fs, false)
    }

    override fun onPause() {
        super.onPause()
        if (isMultiWindowModeHack) {
            isMultiWindowModeHack = false
        } else {
            stopLoading = true
        }
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        isMultiWindowModeHack = isInMultiWindowMode
    }

    private fun setupViews() {
        // this value is expensive to compute but doesn't change during a single runtime
        overlayRangeTopPx = UIUtils.dp2px(this, OVERLAY_RANGE_TOP_DP).toFloat()
        overlayRangeBotPx = UIUtils.dp2px(this, OVERLAY_RANGE_BOT_DP).toFloat()

        ViewUtils.setViewElevation(binding.readingOverlayLeft, OVERLAY_ELEVATION_DP)
        ViewUtils.setViewElevation(binding.readingOverlayRight, OVERLAY_ELEVATION_DP)
        ViewUtils.setViewElevation(binding.readingOverlayText, OVERLAY_ELEVATION_DP)
        ViewUtils.setViewElevation(binding.readingOverlaySend, OVERLAY_ELEVATION_DP)
        ViewUtils.setViewElevation(binding.readingOverlayProgress, OVERLAY_ELEVATION_DP)
        ViewUtils.setViewElevation(binding.readingOverlayProgressLeft, OVERLAY_ELEVATION_DP)
        ViewUtils.setViewElevation(binding.readingOverlayProgressRight, OVERLAY_ELEVATION_DP)

        // this likes to default to 'on' for some platforms
        enableProgressCircle(binding.readingOverlayProgressLeft, false)
        enableProgressCircle(binding.readingOverlayProgressRight, false)

        supportFragmentManager.findFragmentByTag(ReadingPagerFragment::class.java.name)
                ?: supportFragmentManager.commit {
                    add(R.id.activity_reading_container, ReadingPagerFragment.newInstance(), ReadingPagerFragment::class.java.name)
                }
    }

    private fun setupListeners() {
        binding.readingOverlayText.setOnClickListener { overlayTextClick() }
        binding.readingOverlaySend.setOnClickListener { overlaySendClick() }
        binding.readingOverlayLeft.setOnClickListener { overlayLeftClick() }
        binding.readingOverlayRight.setOnClickListener { overlayRightClick() }
        binding.readingOverlayProgress.setOnClickListener { overlayProgressCountClick() }
    }

    private fun setupObservers() {
        storiesViewModel.activeStoriesLiveData.observe(this) {
            setCursorData(it)
        }
    }

    private fun getActiveStoriesCursor(finishOnInvalidFs: Boolean = false) {
        fs?.let {
            storiesViewModel.getActiveStories(it)
        } ?: run {
            if (finishOnInvalidFs) {
                Log.e(this.javaClass.name, "can't create activity, no feedset ready")
                // this is probably happening in a finalisation cycle or during a crash, pop the activity stack
                finish()
            }
        }
    }

    private fun setCursorData(cursor: Cursor) {
        if (!dbHelper.isFeedSetReady(fs)) {
            com.newsblur.util.Log.i(this.javaClass.name, "stale load")
            // the system can and will re-use activities, so during the initial mismatch of
            // data, don't show the old stories
            pager!!.visibility = View.INVISIBLE
            binding.readingEmptyViewText.visibility = View.VISIBLE
            stories = null
            triggerRefresh(AppConstants.READING_STORY_PRELOAD)
            return
        }

        // swapCursor() will asynch process the new cursor and fully update the pager,
        // update child fragments, and then call pagerUpdated()
        readingAdapter?.swapCursor(cursor, pager)

        stories = cursor

        com.newsblur.util.Log.d(this.javaClass.name, "loaded cursor with count: " + cursor.count)
        if (cursor.count < 1) {
            triggerRefresh(AppConstants.READING_STORY_PRELOAD)
        }
    }

    /**
     * notify the activity that the dataset for the pager has fully been updated
     */
    fun pagerUpdated() {
        // see if we are just starting and need to jump to a target story
        skipPagerToStoryHash()

        if (unreadSearchActive) {
            // if we left this flag high, we were looking for an unread, but didn't find one;
            // now that we have more stories, look again.
            nextUnread()
        }

        updateOverlayNav()
        updateOverlayText()
    }

    private fun skipPagerToStoryHash() {
        // if we already started and found our target story, this will be unset
        if (storyHash == null) {
            pager!!.visibility = View.VISIBLE
            binding.readingEmptyViewText.visibility = View.INVISIBLE
            return
        }
        val position: Int = if (storyHash == FIND_FIRST_UNREAD) {
            readingAdapter!!.findFirstUnread()
        } else {
            readingAdapter!!.findHash(storyHash)
        }

        if (stopLoading) return

        if (position >= 0) {
            pager!!.setCurrentItem(position, false)
            onPageSelected(position)
            // now that the pager is getting the right story, make it visible
            pager!!.visibility = View.VISIBLE
            binding.readingEmptyViewText.visibility = View.INVISIBLE
            storyHash = null
            return
        }

        // if the story wasn't found, try to get more stories into the cursor
        checkStoryCount(readingAdapter!!.count + 1)
    }

    /*
     * The key component of this activity is the pager, which in order to correctly use
     * child fragments for stories, needs to be within an enclosing fragment.  Because
     * the view heirarchy of that fragment will have a different lifecycle than the
     * activity, we need a way to get access to the pager when it is created and only
     * then can we set it up.
     */
    fun offerPager(pager: ViewPager, childFragmentManager: FragmentManager) {
        this.pager = pager

        // since it might start on the wrong story, create the pager as invisible
        pager.visibility = View.INVISIBLE
        pager.pageMargin = UIUtils.dp2px(this, 1)

        when (PrefsUtils.getSelectedTheme(this)) {
            ThemeValue.LIGHT -> pager.setPageMarginDrawable(R.drawable.divider_light)
            ThemeValue.DARK, ThemeValue.BLACK -> pager.setPageMarginDrawable(R.drawable.divider_dark)
            ThemeValue.AUTO -> {
                when (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) {
                    Configuration.UI_MODE_NIGHT_YES -> pager.setPageMarginDrawable(R.drawable.divider_dark)
                    Configuration.UI_MODE_NIGHT_NO -> pager.setPageMarginDrawable(R.drawable.divider_light)
                    Configuration.UI_MODE_NIGHT_UNDEFINED -> pager.setPageMarginDrawable(R.drawable.divider_light)
                }
            }
            else -> {
            }
        }

        var showFeedMetadata = true
        if (fs!!.isSingleNormal) showFeedMetadata = false
        var sourceUserId: String? = null
        if (fs!!.singleSocialFeed != null) sourceUserId = fs!!.singleSocialFeed.key
        readingAdapter = ReadingAdapter(childFragmentManager, sourceUserId, showFeedMetadata, this, dbHelper)

        pager.adapter = readingAdapter

        // if the first story in the list was "viewed" before the page change listener was set,
        // the calback was probably missed
        if (storyHash == null) {
            onPageSelected(pager.currentItem)
        }

        updateOverlayNav()
        enableOverlays()
    }

    /**
     * Query the DB for the current unreadcount for this view.
     */
    private val unreadCount: Int
        // saved stories and global shared stories don't have unreads
        get() {
            // saved stories and global shared stories don't have unreads
            if (fs!!.isAllSaved || fs!!.isGlobalShared) return 0
            val result = dbHelper.getUnreadCount(fs, intelState)
            return if (result < 0) 0 else result
        }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return if (item.itemId == android.R.id.home) {
            finish()
            true
        } else {
            super.onOptionsItemSelected(item)
        }
    }

    override fun handleUpdate(updateType: Int) {
        if (updateType and UPDATE_REBUILD != 0) {
            finish()
        }
        if (updateType and UPDATE_STATUS != 0) {
            enableMainProgress(NBSyncService.isFeedSetSyncing(fs, this))
            var syncStatus = NBSyncService.getSyncStatusMessage(this, true)
            if (syncStatus != null) {
                if (AppConstants.VERBOSE_LOG) {
                    syncStatus += UIUtils.getMemoryUsageDebug(this)
                }
                binding.readingSyncStatus.text = syncStatus
                binding.readingSyncStatus.visibility = View.VISIBLE
            } else {
                binding.readingSyncStatus.visibility = View.GONE
            }
        }
        if (updateType and UPDATE_STORY != 0) {
            getActiveStoriesCursor()
            updateOverlayNav()
        }

        readingFragment?.handleUpdate(updateType)
    }

    // interface OnPageChangeListener
    override fun onPageScrollStateChanged(arg0: Int) {}

    override fun onPageScrolled(arg0: Int, arg1: Float, arg2: Int) {}

    override fun onPageSelected(position: Int) {
        lifecycleScope.executeAsyncTask(
                doInBackground = {
                    readingAdapter?.let { readingAdapter ->
                        val story = readingAdapter.getStory(position)
                        if (story != null) {
                            synchronized(pageHistory) {
                                // if the history is just starting out or the last entry in it isn't this page, add this page
                                if (pageHistory.size < 1 || story != pageHistory[pageHistory.size - 1]) {
                                    pageHistory.add(story)
                                }
                            }

                            triggerMarkStoryReadBehavior(story)
                        }
                        checkStoryCount(position)
                        updateOverlayText()
                        enableOverlays()
                    }
                }
        )
    }

    // interface ScrollChangeListener
    override fun scrollChanged(hPos: Int, vPos: Int, currentWidth: Int, currentHeight: Int) {
        // only update overlay alpha every few pixels. modern screens are so dense that it
        // is way overkill to do it on every pixel
        if (abs(lastVScrollPos - vPos) < 2) return
        lastVScrollPos = vPos

        val scrollMax = currentHeight - binding.root.measuredHeight
        val posFromBot = scrollMax - vPos

        var newAlpha = 0.0f
        if (vPos < overlayRangeTopPx && posFromBot < overlayRangeBotPx) {
            // if we have a super-tiny scroll window such that we never leave either top or bottom,
            // just leave us at full alpha.
            newAlpha = 1.0f
        } else if (vPos < overlayRangeTopPx) {
            val delta = overlayRangeTopPx - vPos.toFloat()
            newAlpha = delta / overlayRangeTopPx
        } else if (posFromBot < overlayRangeBotPx) {
            val delta = overlayRangeBotPx - posFromBot.toFloat()
            newAlpha = delta / overlayRangeBotPx
        }

        setOverlayAlpha(newAlpha)
    }

    private fun setOverlayAlpha(a: Float) {
        // check to see if the device even has room for all the overlays, moving some to overflow if not
        val widthPX = binding.root.measuredWidth
        var overflowExtras = false
        if (widthPX != 0) {
            val widthDP = UIUtils.px2dp(this, widthPX)
            if (widthDP < OVERLAY_MIN_WIDTH_DP) {
                overflowExtras = true
            }
        }

        val _overflowExtras = overflowExtras
        runOnUiThread {
            UIUtils.setViewAlpha(binding.readingOverlayLeft, a, true)
            UIUtils.setViewAlpha(binding.readingOverlayRight, a, true)
            UIUtils.setViewAlpha(binding.readingOverlayProgress, a, true)
            UIUtils.setViewAlpha(binding.readingOverlayText, a, true)
            UIUtils.setViewAlpha(binding.readingOverlaySend, a, !_overflowExtras)
        }
    }

    /**
     * Make visible and update the overlay UI.
     */
    fun enableOverlays() {
        setOverlayAlpha(1.0f)
    }

    fun disableOverlays() {
        setOverlayAlpha(0.0f)
    }

    /**
     * Update the next/back overlay UI after the read-state of a story changes or we navigate in any way.
     */
    private fun updateOverlayNav() {
        val currentUnreadCount = unreadCount
        if (currentUnreadCount > startingUnreadCount) {
            startingUnreadCount = currentUnreadCount
        }
        binding.readingOverlayLeft.isEnabled = getLastReadPosition(false) != -1
        binding.readingOverlayRight.setText(if (currentUnreadCount > 0) R.string.overlay_next else R.string.overlay_done)
        if (currentUnreadCount > 0) {
            binding.readingOverlayRight.setBackgroundResource(UIUtils.getThemedResource(this, R.attr.selectorOverlayBackgroundRight, android.R.attr.background))
        } else {
            binding.readingOverlayRight.setBackgroundResource(UIUtils.getThemedResource(this, R.attr.selectorOverlayBackgroundRightDone, android.R.attr.background))
        }

        if (startingUnreadCount == 0) {
            // sessions with no unreads just show a full progress bar
            binding.readingOverlayProgress.max = 1
            binding.readingOverlayProgress.progress = 1
        } else {
            val unreadProgress = startingUnreadCount - currentUnreadCount
            binding.readingOverlayProgress.max = startingUnreadCount
            binding.readingOverlayProgress.progress = unreadProgress
        }
        binding.readingOverlayProgress.invalidate()

        invalidateOptionsMenu()
    }

    private fun updateOverlayText() {
        runOnUiThread(Runnable {
            val item = readingFragment ?: return@Runnable
            if (item.selectedViewMode == DefaultFeedView.STORY) {
                binding.readingOverlayText.setBackgroundResource(UIUtils.getThemedResource(this@Reading, R.attr.selectorOverlayBackgroundText, android.R.attr.background))
                binding.readingOverlayText.setText(R.string.overlay_text)
            } else {
                binding.readingOverlayText.setBackgroundResource(UIUtils.getThemedResource(this@Reading, R.attr.selectorOverlayBackgroundStory, android.R.attr.background))
                binding.readingOverlayText.setText(R.string.overlay_story)
            }
        })
    }

//    override fun onWindowFocusChanged(hasFocus: Boolean) {
//        // this callback is a good API-level-independent way to tell when the root view size/layout changes
//        super.onWindowFocusChanged(hasFocus)
//        contentView = findViewById(android.R.id.content)
//    }

    /**
     * While navigating the story list and at the specified position, see if it is possible
     * and desirable to start loading more stories in the background.  Note that if a load
     * is triggered, this method will be called again by the callback to ensure another
     * load is not needed and all latches are tripped.
     */
    private fun checkStoryCount(position: Int) {
        if (stories == null) {
            triggerRefresh(position + AppConstants.READING_STORY_PRELOAD)
        } else {
            if (AppConstants.VERBOSE_LOG) {
                Log.d(this.javaClass.name, String.format("story %d of %d selected, stopLoad: %b", position, stories!!.count, stopLoading))
            }
            // if the pager is at or near the number of stories loaded, check for more unless we know we are at the end of the list
            if (position + AppConstants.READING_STORY_PRELOAD >= stories!!.count) {
                triggerRefresh(position + AppConstants.READING_STORY_PRELOAD)
            }
        }
    }

    private fun enableMainProgress(enabled: Boolean) {
        enableProgressCircle(binding.readingOverlayProgressRight, enabled)
    }

    fun enableLeftProgressCircle(enabled: Boolean) {
        enableProgressCircle(binding.readingOverlayProgressLeft, enabled)
    }

    private fun enableProgressCircle(view: CircularProgressIndicator, enabled: Boolean) {
        runOnUiThread {
            if (enabled) {
                view.progress = 0
                view.visibility = View.VISIBLE
            } else {
                view.progress = 100
                view.visibility = View.GONE
            }
        }
    }

    private fun triggerRefresh(desiredStoryCount: Int) {
        if (!stopLoading) {
            var currentCount: Int? = null
            if (stories != null) currentCount = stories!!.count
            val gotSome = NBSyncService.requestMoreForFeed(fs, desiredStoryCount, currentCount)
            if (gotSome) triggerSync()
        }
    }

    /**
     * Click handler for the righthand overlay nav button.
     */
    private fun overlayRightClick() {
        if (unreadCount <= 0) {
            // if there are no unread stories, go back to the feed list
            val i = Intent(this, Main::class.java)
            i.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP
            startActivity(i)
            finish()
        } else {
            // if there are unreads, go to the next one
            lifecycleScope.executeAsyncTask(
                    doInBackground = { nextUnread() }
            )
        }
    }

    /**
     * Search our set of stories for the next unread one.
     */
    private fun nextUnread() {
        unreadSearchActive = true

        // if we somehow got tapped before construction or are running during destruction, stop and
        // let either finish. search will happen when the cursor is pushed.
        if (pager == null || readingAdapter == null) return

        var unreadFound = false
        // start searching just after the current story
        val currentIndex = pager!!.currentItem
        var candidate = currentIndex + 1
        unreadSearch@ while (!unreadFound) {
            // if we've reached the end of the list, start searching backward from the current story
            if (candidate >= readingAdapter!!.count) {
                candidate = currentIndex - 1
            }
            // if we have looked all the way back to the first story, there aren't any left
            if (candidate < 0) {
                break@unreadSearch
            }
            val story = readingAdapter!!.getStory(candidate)
            if (stopLoading) {
                // this activity was ended before we finished. just stop.
                unreadSearchActive = false
                return
            }
            // iterate through the stories in our cursor until we find an unread one
            if (story != null) {
                unreadFound = if (story.read) {
                    if (candidate > currentIndex) {
                        // if we are still searching past the current story, search forward
                        candidate++
                    } else {
                        // if we hit the end and re-started before the current story, search backward
                        candidate--
                    }
                    continue@unreadSearch
                } else {
                    true
                }
            }
            // if we didn't continue or break, the cursor probably changed out from under us, so stop.
            break@unreadSearch
        }

        if (unreadFound) {
            // jump to the story we found
            val page = candidate
            runOnUiThread { pager!!.setCurrentItem(page, true) }
            // disable the search flag, as we are done
            unreadSearchActive = false
        } else {
            // We didn't find a story, so we should trigger a check to see if the API can load any more.
            // First, though, double check that there are even any left, as there may have been a delay
            // between marking an earlier one and double-checking counts.
            if (unreadCount <= 0) {
                unreadSearchActive = false
            } else {
                // trigger a check to see if there are any more to search before proceeding. By leaving the
                // unreadSearchActive flag high, this method will be called again when a new cursor is loaded
                checkStoryCount(readingAdapter!!.count + 1)
            }
        }
    }

    /**
     * Click handler for the lefthand overlay nav button.
     */
    private fun overlayLeftClick() {
        val targetPosition = getLastReadPosition(true)
        if (targetPosition != -1) {
            pager!!.setCurrentItem(targetPosition, true)
        } else {
            Log.e(this.javaClass.name, "reading history contained item not found in cursor.")
        }
    }

    /**
     * Get the pager position of the last story read during this activity or -1 if there is nothing
     * in the history.
     *
     * @param trimHistory optionally trim the history of the currently displayed page iff the
     * back button has been pressed.
     */
    private fun getLastReadPosition(trimHistory: Boolean): Int {
        synchronized(pageHistory) {
            // the last item is always the currently shown page, do not count it
            if (pageHistory.size < 2) {
                return -1
            }

            val targetStory = pageHistory[pageHistory.size - 2]
            val targetPosition = readingAdapter!!.getPosition(targetStory)
            if (trimHistory && targetPosition != -1) {
                pageHistory.removeAt(pageHistory.size - 1)
            }
            return targetPosition
        }
    }

    /**
     * Click handler for the progress indicator on the righthand overlay nav button.
     */
    private fun overlayProgressCountClick() {
        val unreadText = getString(if (unreadCount == 1) R.string.overlay_count_toast_1 else R.string.overlay_count_toast_N)
        Toast.makeText(this, String.format(unreadText, unreadCount), Toast.LENGTH_SHORT).show()
    }

    private fun overlaySendClick() {
        if (readingAdapter == null || pager == null) return
        val story = readingAdapter!!.getStory(pager!!.currentItem)
        feedUtils.sendStoryUrl(story, this)
    }

    private fun overlayTextClick() {
        val item = readingFragment ?: return
        lifecycleScope.executeAsyncTask(
                doInBackground = { item.switchSelectedViewMode() }
        )
    }

    private val readingFragment: ReadingItemFragment?
        get() = if (readingAdapter == null || pager == null) null
        else readingAdapter!!.getExistingItem(pager!!.currentItem)

    fun viewModeChanged() {
        var frag = readingAdapter!!.getExistingItem(pager!!.currentItem)
        frag?.viewModeChanged()
        // fragments to the left or the right may have already preloaded content and need to also switch
        frag = readingAdapter!!.getExistingItem(pager!!.currentItem - 1)
        frag?.viewModeChanged()
        frag = readingAdapter!!.getExistingItem(pager!!.currentItem + 1)
        frag?.viewModeChanged()
        updateOverlayText()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        return if (isVolumeKeyNavigationEvent(keyCode)) {
            processVolumeKeyNavigationEvent(keyCode)
            true
        } else {
            super.onKeyDown(keyCode, event)
        }
    }

    private fun isVolumeKeyNavigationEvent(keyCode: Int): Boolean = volumeKeyNavigation != VolumeKeyNavigation.OFF
            && (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP)

    private fun processVolumeKeyNavigationEvent(keyCode: Int) {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN && volumeKeyNavigation == VolumeKeyNavigation.DOWN_NEXT ||
                keyCode == KeyEvent.KEYCODE_VOLUME_UP && volumeKeyNavigation == VolumeKeyNavigation.UP_NEXT) {
            if (pager == null) return
            val nextPosition = pager!!.currentItem + 1
            if (nextPosition < readingAdapter!!.count) {
                try {
                    pager!!.currentItem = nextPosition
                } catch (e: Exception) {
                    // Just in case cursor changes.
                }
            }
        } else {
            if (pager == null) return
            val nextPosition = pager!!.currentItem - 1
            if (nextPosition >= 0) {
                try {
                    pager!!.currentItem = nextPosition
                } catch (e: Exception) {
                    // Just in case cursor changes.
                }
            }
        }
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        // Required to prevent the default sound playing when the volume key is pressed
        return if (isVolumeKeyNavigationEvent(keyCode)) {
            true
        } else {
            super.onKeyUp(keyCode, event)
        }
    }

    private fun triggerMarkStoryReadBehavior(story: Story) {
        markStoryReadJob?.cancel()
        if (story.read) return

        val delayMillis = markStoryReadBehavior.getDelayMillis()
        if (delayMillis >= 0) {
            markStoryReadJob = createMarkStoryReadJob(story, delayMillis).also {
                it.start()
            }
        }
    }

    private fun createMarkStoryReadJob(story: Story, delayMillis: Long): Job =
            lifecycleScope.launch(Dispatchers.Default) {
                if (isActive) delay(delayMillis)
                if (isActive) feedUtils.markStoryAsRead(story, this@Reading)
            }

    companion object {
        const val EXTRA_FEEDSET = "feed_set"
        const val EXTRA_STORY_HASH = "story_hash"
        const val EXTRA_STORY = "story"
        private const val BUNDLE_STARTING_UNREAD = "starting_unread"

        /** special value for starting story hash that jumps to the first unread.  */
        const val FIND_FIRST_UNREAD = "FIND_FIRST_UNREAD"
        private const val OVERLAY_ELEVATION_DP = 1.5f
        private const val OVERLAY_RANGE_TOP_DP = 40
        private const val OVERLAY_RANGE_BOT_DP = 60

        /** The minimum screen width (in DP) needed to show all the overlay controls.  */
        private const val OVERLAY_MIN_WIDTH_DP = 355
    }
}