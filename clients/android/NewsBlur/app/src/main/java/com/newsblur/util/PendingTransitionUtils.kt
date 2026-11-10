@file:Suppress("DEPRECATION")

package com.newsblur.util

import android.app.Activity
import android.os.Build
import com.newsblur.R

object PendingTransitionUtils {
    // PendingTransitionUtils.kt slides a new screen in from the end edge and back out toward it, so
    // the slides mirror in Arabic and Hebrew along with the back swipes.
    private fun isRtl(activity: Activity): Boolean = UIUtils.towardEndSign(activity) < 0f

    @JvmStatic
    fun overrideEnterTransition(activity: Activity) {
        val enter = if (isRtl(activity)) R.anim.slide_in_from_left else R.anim.slide_in_from_right
        val exit = if (isRtl(activity)) R.anim.slide_out_to_right else R.anim.slide_out_to_left
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            activity.overrideActivityTransition(
                Activity.OVERRIDE_TRANSITION_OPEN,
                enter,
                exit,
            )
        } else {
            activity.overridePendingTransition(
                enter,
                exit,
            )
        }
    }

    @JvmStatic
    fun overrideNoEnterTransition(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            activity.overrideActivityTransition(
                Activity.OVERRIDE_TRANSITION_OPEN,
                0,
                0,
            )
        } else {
            activity.overridePendingTransition(
                0,
                0,
            )
        }
    }

    @JvmStatic
    fun overrideExitTransition(activity: Activity) {
        val enter = if (isRtl(activity)) R.anim.slide_in_from_right else R.anim.slide_in_from_left
        val exit = if (isRtl(activity)) R.anim.slide_out_to_left else R.anim.slide_out_to_right
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            activity.overrideActivityTransition(
                Activity.OVERRIDE_TRANSITION_CLOSE,
                enter,
                exit,
            )
        } else {
            activity.overridePendingTransition(enter, exit)
        }
    }

    @JvmStatic
    fun overrideNoExitTransition(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            activity.overrideActivityTransition(
                Activity.OVERRIDE_TRANSITION_CLOSE,
                0,
                0,
            )
        } else {
            activity.overridePendingTransition(0, 0)
        }
    }
}
