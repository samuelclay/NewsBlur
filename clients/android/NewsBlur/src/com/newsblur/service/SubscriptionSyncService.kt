package com.newsblur.service

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import com.newsblur.subscription.SubscriptionManagerImpl
import com.newsblur.util.AppConstants
import com.newsblur.util.Log
import com.newsblur.util.NBScope
import com.newsblur.util.PrefsUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Service to sync user subscription with NewsBlur backend.
 *
 * Mostly interested in handling the state where there is an active
 * subscription in Play Store but NewsBlur doesn't know about it.
 * This could occur when the user has renewed the subscription
 * via Play Store.
 */
class SubscriptionSyncService : JobService() {

    override fun onStartJob(params: JobParameters?): Boolean {
        Log.d(this, "onStartJob")
        if (!PrefsUtils.hasCookie(this)) {
            // no user authenticated
            return false
        }

        NBScope.launch(Dispatchers.Default) {
            val subscriptionManager = SubscriptionManagerImpl(this@SubscriptionSyncService, this)
            val job = subscriptionManager.syncActiveSubscription()
            job.invokeOnCompletion {
                Log.d(this, "sync active subscription completed.")
                // manually trigger jobFinished after work is done
                jobFinished(params, false)
            }
        }

        return true // returning true due to background thread work
    }

    override fun onStopJob(params: JobParameters?): Boolean = false

    companion object {

        private const val JOB_ID = 2021

        private fun createJobInfo(context: Context): JobInfo = JobInfo.Builder(JOB_ID,
                ComponentName(context, SubscriptionSyncService::class.java))
                .apply {
                    // sync every 24 hours
                    setPeriodic(AppConstants.BG_SUBSCRIPTION_SYNC_CYCLE_MILLIS)
                    setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                    setBackoffCriteria(JobInfo.DEFAULT_INITIAL_BACKOFF_MILLIS, JobInfo.BACKOFF_POLICY_EXPONENTIAL)
                    setPersisted(true)
                }.build()

        fun schedule(context: Context) {
            val jobScheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            val job = jobScheduler.allPendingJobs.find { it.id == JOB_ID }
            if (job == null) {
                val result: Int = jobScheduler.schedule(createJobInfo(context))
                Log.d(this, "Scheduled subscription result: ${if (result == JobScheduler.RESULT_FAILURE) "failed" else "completed"}")
            }
        }

        @JvmStatic
        fun cancel(context: Context) {
            val jobScheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            jobScheduler.allPendingJobs.find { it.id == JOB_ID }?.let {
                jobScheduler.cancel(JOB_ID)
                Log.d(this, "Cancel sync job.")
            }
        }
    }
}