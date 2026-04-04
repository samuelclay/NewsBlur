package com.newsblur.activity

import android.app.Activity
import com.google.android.gms.tasks.Task
import com.google.android.play.core.review.ReviewInfo
import com.google.android.play.core.review.ReviewManager
import com.google.android.play.core.review.ReviewManagerFactory
import com.newsblur.preference.PrefsRepo

/**
 * Encapsulates Google Play in-app review logic. F-Droid replaces this file
 * with a no-op stub so no Play Services code is needed.
 */
class InAppReviewHelper(
    private val activity: Activity,
    private val prefsRepo: PrefsRepo,
) {

    private var reviewManager: ReviewManager? = null
    private var reviewInfo: ReviewInfo? = null

    fun check() {
        if (!prefsRepo.hasInAppReviewed()) {
            reviewManager = ReviewManagerFactory.create(activity)
            reviewManager
                ?.requestReviewFlow()
                ?.addOnCompleteListener { task ->
                    if (task.isSuccessful) {
                        reviewInfo = task.getResult()
                    }
                }
        }
    }

    /**
     * If the user qualifies for an in-app review prompt and is using
     * button navigation, launch the review flow and call [onComplete]
     * when it finishes. Returns true if the back press was intercepted.
     */
    fun interceptBackPress(isGestureNavigation: Boolean, onComplete: () -> Unit): Boolean {
        if (reviewInfo == null || isGestureNavigation) return false
        val flow = reviewManager!!.launchReviewFlow(activity, reviewInfo!!)
        flow.addOnCompleteListener { _: Task<Void?>? ->
            prefsRepo.setInAppReviewed()
            onComplete()
        }
        return true
    }
}
