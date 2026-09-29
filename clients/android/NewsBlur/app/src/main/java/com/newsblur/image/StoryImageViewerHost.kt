package com.newsblur.image

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import com.newsblur.util.PendingTransitionUtils

/**
 * A transparent, full window home for StoryImageViewer.kt in a tablet split. A Dialog is clipped
 * to its activity's pane, so a photo tapped in the reader pane would only cover the reader and
 * leave the story list showing beside it. StorySplitView.kt always expands this activity to the
 * whole window, so the same viewer Dialog attached here covers the story list too, while the
 * split stays laid out underneath for the photo's open and close animation.
 */
class StoryImageViewerHost : ComponentActivity() {
    private var viewer: StoryImageViewer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        PendingTransitionUtils.overrideNoEnterTransition(this)
        val open = pendingOpen
        pendingOpen = null
        // A host recreated after process death has no photo to show.
        if (open == null || savedInstanceState != null) {
            finishWithoutAnimation()
            return
        }
        viewer = open(this)
    }

    /** ReadingItemFragment.kt calls this once the viewer Dialog has closed. */
    fun onViewerClosed() {
        viewer = null
        finishWithoutAnimation()
    }

    override fun onDestroy() {
        // If the host goes first, closing the Dialog still clears ReadingItemFragment.kt's viewer state.
        viewer?.dismiss()
        viewer = null
        super.onDestroy()
    }

    private fun finishWithoutAnimation() {
        if (!isFinishing) finish()
        PendingTransitionUtils.overrideNoExitTransition(this)
    }

    companion object {
        private var pendingOpen: ((StoryImageViewerHost) -> StoryImageViewer)? = null

        /** Starts the host and hands it the viewer to show, built by [open] against the host. */
        @JvmStatic
        fun show(
            from: Activity,
            open: (StoryImageViewerHost) -> StoryImageViewer,
        ) {
            pendingOpen = open
            from.startActivity(Intent(from, StoryImageViewerHost::class.java))
            PendingTransitionUtils.overrideNoEnterTransition(from)
        }
    }
}
