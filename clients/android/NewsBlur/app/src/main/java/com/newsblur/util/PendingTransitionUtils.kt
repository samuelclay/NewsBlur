@file:Suppress("DEPRECATION")

package com.newsblur.util

import android.app.Activity
import android.os.Build
import com.newsblur.R

object PendingTransitionUtils {
    @JvmStatic
    fun overrideEnterTransition(activity: Activity) {
        if (Build.VERSION.SDK_INT >= 34) return
        activity.overridePendingTransition(
            R.anim.slide_in_from_right,
            R.anim.slide_out_to_left,
        )
    }

    @JvmStatic
    fun overrideNoEnterTransition(activity: Activity) {
        if (Build.VERSION.SDK_INT >= 34) return
        activity.overridePendingTransition(
            0,
            0,
        )
    }

    @JvmStatic
    fun overrideExitTransition(activity: Activity) {
        if (Build.VERSION.SDK_INT >= 34) return
        activity.overridePendingTransition(
            R.anim.slide_in_from_left,
            R.anim.slide_out_to_right,
        )
    }

    @JvmStatic
    fun overrideNoExitTransition(activity: Activity) {
        if (Build.VERSION.SDK_INT >= 34) return
        activity.overridePendingTransition(0, 0)
    }
}
