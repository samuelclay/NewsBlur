package com.newsblur.activity

import android.app.Activity
import com.newsblur.preference.PrefsRepo

/** F-Droid has no Play review flow; FeedItemsList.kt keeps its normal back navigation. */
@Suppress("UNUSED_PARAMETER")
class InAppReviewHelper(
    activity: Activity,
    prefsRepo: PrefsRepo,
) {
    fun check() = Unit

    fun interceptBackPress(
        isGestureNavigation: Boolean,
        onComplete: () -> Unit,
    ): Boolean = false
}
