package com.newsblur.view

// ReaderBackGesturePolicy.kt selects which owner handles the reader's left-edge back gesture.
internal fun readerUsesSystemBackGesture(sdkInt: Int, hasSystemBackGesture: Boolean): Boolean =
    sdkInt >= 34 && hasSystemBackGesture
