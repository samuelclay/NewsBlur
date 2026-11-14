package com.newsblur.service

import android.app.job.JobParameters
import android.app.job.JobService
import android.content.Context

/** AndroidManifest.xml disables this service in F-Droid; account status still syncs through the API. */
class SubscriptionSyncService : JobService() {
    override fun onStartJob(params: JobParameters?): Boolean = false

    override fun onStopJob(params: JobParameters?): Boolean = false

    companion object {
        @Suppress("UNUSED_PARAMETER")
        fun schedule(context: Context) = Unit

        @JvmStatic
        @Suppress("UNUSED_PARAMETER")
        fun cancel(context: Context) = Unit
    }
}
