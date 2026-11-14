package com.newsblur.activity

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.widget.AppCompatImageButton
import com.newsblur.R
import com.newsblur.util.StorySplitView
import dagger.hilt.android.AndroidEntryPoint
import java.lang.ref.WeakReference

/**
 * Main.java's feeds beside ItemsList.java on tablets. StorySplitView.kt places this secondary
 * activity at the start edge; opening Reading.kt replaces it and moves titles to that edge.
 * Each view can also fill the window, independently of the other views' saved choices.
 */
@AndroidEntryPoint
class FeedListDrawer : Main() {
    override fun isFeedDrawer(): Boolean = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (isFinishing) return
        activeDrawer = WeakReference(this)
        val style = TypedValue()
        if (theme.resolveAttribute(R.attr.listBackground, style, true)) {
            val attrs =
                obtainStyledAttributes(style.resourceId, intArrayOf(android.R.attr.background))
            findViewById<View>(android.R.id.content).background = attrs.getDrawable(0)
            attrs.recycle()
        }
        findViewById<AppCompatImageButton>(R.id.main_fullscreen_button).setOnClickListener {
            StorySplitView.setFeedListFullscreen(this, !StorySplitView.isFeedListFullscreen(this))
            updateFullscreenButton()
        }
        StorySplitView.trackSplit(this) { updateFullscreenButton() }
        registerBackNavigation()
        findViewById<View>(R.id.toolbar).addOnLayoutChangeListener { view, _, _, _, _, _, _, _, _ ->
            val widthDp = view.width / resources.displayMetrics.density
            findViewById<android.widget.TextView>(R.id.main_sync_status_text).maxWidth =
                ((widthDp - 270f).coerceIn(0f, 140f) * resources.displayMetrics.density).toInt()
        }
    }

    override fun onResume() {
        super.onResume()
        updateFullscreenButton()
        if (!StorySplitView.isFeedListFullscreen(this)) storyListBeneath()?.startDeferredStories()
    }

    override fun onDestroy() {
        if (activeDrawer.get() === this) activeDrawer.clear()
        super.onDestroy()
    }

    private fun updateFullscreenButton() {
        if (isFinishing) return
        findViewById<AppCompatImageButton>(R.id.main_fullscreen_button)?.apply {
            visibility =
                if (StorySplitView.canToggleFeedListFullscreen()) View.VISIBLE else View.GONE
            val fullscreen = StorySplitView.isFeedListFullscreen(this@FeedListDrawer)
            setImageResource(
                if (fullscreen) R.drawable.ic_reader_fullscreen_exit else R.drawable.ic_reader_fullscreen
            )
            contentDescription =
                getString(
                    if (fullscreen) R.string.feed_list_exit_fullscreen else R.string.feed_list_enter_fullscreen
                )
            tooltipText = contentDescription
        }
    }

    @Deprecated("Activity result APIs")
    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        if (StorySplitView.isStoryList(intent)) {
            storyListBeneath()?.let { titles ->
                titles.switchStoryList(intent)
                StorySplitView.showStoryTitles(this)
                return
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        @Suppress("DEPRECATION")
        super.startActivityForResult(intent, requestCode, options)
    }

    private fun registerBackNavigation() {
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() = backFromFeeds()
            }
        )
    }

    private fun backFromFeeds() {
        moveTaskToBack(true)
    }

    private fun storyListBeneath(): ItemsList? = ItemsList.peekReadingLaunchParent(taskId)?.takeIf {
        !it.isFinishing
    }

    companion object {
        // ItemsList.java defers expensive loading until the native pane transition completes.
        const val SLIDE_DURATION_MS = 280L
        private var activeDrawer = WeakReference<FeedListDrawer>(null)

        @JvmStatic
        fun peek(taskId: Int): FeedListDrawer? = activeDrawer.get()?.takeIf {
            !it.isFinishing &&
                !it.isDestroyed &&
                it.taskId == taskId
        }

        @JvmStatic
        @JvmOverloads
        fun open(from: Activity, forceShowFeedId: String? = null, focusFeeds: Boolean = true) {
            StorySplitView.prepareFeedList(from, focusFeeds)
            if (peek(from.taskId) != null) return
            from.startActivity(
                Intent(
                    from,
                    FeedListDrawer::class.java
                ).putExtra(Main.EXTRA_FORCE_SHOW_FEED_ID, forceShowFeedId)
            )
        }
    }
}
