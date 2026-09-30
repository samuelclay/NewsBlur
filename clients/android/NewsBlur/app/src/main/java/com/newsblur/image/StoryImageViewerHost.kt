package com.newsblur.image

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import com.newsblur.util.PendingTransitionUtils
import java.util.UUID

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
        val open = intent.getStringExtra(EXTRA_TOKEN)?.let { token -> pendingOpens.remove(token) }
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
        private const val EXTRA_TOKEN = "story_image_viewer_host_token"

        // Photos waiting for their host, keyed by a token that travels in the host's intent, so
        // each reader only ever touches its own.
        private val pendingOpens = mutableMapOf<String, (StoryImageViewerHost) -> StoryImageViewer>()

        /**
         * Starts the host and hands it the viewer to show, built by [open] against the host.
         * Returns the token that cancelPending takes.
         */
        @JvmStatic
        fun show(
            from: Activity,
            open: (StoryImageViewerHost) -> StoryImageViewer,
        ): String {
            val token = UUID.randomUUID().toString()
            pendingOpens[token] = open
            try {
                from.startActivity(Intent(from, StoryImageViewerHost::class.java).putExtra(EXTRA_TOKEN, token))
            } catch (failure: RuntimeException) {
                pendingOpens.remove(token)
                throw failure
            }
            // On API 34+ that call would store an override on the reader itself, and onCreate
            // already turns off the host's own open animation there.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                PendingTransitionUtils.overrideNoEnterTransition(from)
            }
            return token
        }

        /** Drops a photo whose host never started, so nothing holds on to the reader that asked for it. */
        @JvmStatic
        fun cancelPending(token: String) {
            pendingOpens.remove(token)
        }
    }
}
