package com.newsblur

import android.app.Application
import android.app.job.JobScheduler
import android.content.Context
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.newsblur.service.SubscriptionSyncService
import com.newsblur.util.Log

class NbApplication : Application(), DefaultLifecycleObserver {

    override fun onCreate() {
        super<Application>.onCreate()
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)
        scheduleSubscriptionSync()
    }

    override fun onStart(owner: LifecycleOwner) {
        super.onStart(owner)
        isAppForeground = true
    }

    override fun onStop(owner: LifecycleOwner) {
        super.onStop(owner)
        isAppForeground = false
    }

    private fun scheduleSubscriptionSync() {
        val jobScheduler = getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        val scheduledSubscriptionJob = jobScheduler.allPendingJobs.find { it.id == SubscriptionSyncService.JOB_ID }
        if (scheduledSubscriptionJob == null) {
            val result: Int = jobScheduler.schedule(SubscriptionSyncService.createJobInfo(this))
            Log.d(this, "Scheduled subscription result: ${if (result == JobScheduler.RESULT_FAILURE) "failed" else "completed"}")
        }
    }

    companion object {

        @JvmStatic
        var isAppForeground = false
    }
}