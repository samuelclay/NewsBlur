package com.newsblur.activity

import android.view.View

internal fun prepareReaderSurface(surface: View) {
    // Reading.kt must keep the subtree drawable; zero alpha prevents WebView's first compositor frame.
    // One eight-bit alpha step also avoids rounding down to zero in RenderNodeDrawable.cpp.
    surface.alpha = 1f / 255f
}

/** Reading.kt must wait for the requested article, rather than a prefetched neighboring page. */
internal fun shouldRevealPreparedReader(
    waiting: Boolean,
    pendingTargetHash: String?,
    activeStoryHash: String?,
    readyStoryHash: String,
): Boolean = waiting && pendingTargetHash == null && activeStoryHash == readyStoryHash
