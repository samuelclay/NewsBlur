package com.newsblur

import android.app.Application
import android.os.StrictMode
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.newsblur.util.Log
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class NbApplication : Application(), DefaultLifecycleObserver {

    override fun onCreate() {
        super<Application>.onCreate()
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)
        Log.offerContext(this)

        if (BuildConfig.DEBUG) {
//            StrictMode.setVmPolicy(
//                    StrictMode.VmPolicy.Builder()
//                            .detectLeakedSqlLiteObjects()
//                            .detectLeakedClosableObjects()
//                            .penaltyLog()
//                            .penaltyDeath()
//                            .build()
//            )

            StrictMode.setThreadPolicy(
                    StrictMode.ThreadPolicy.Builder()
                            .detectDiskReads()
                            .detectDiskWrites()
                            .penaltyLog()
                            .build()
            )
        }
    }

    override fun onStart(owner: LifecycleOwner) {
        super.onStart(owner)
        isAppForeground = true
    }

    override fun onStop(owner: LifecycleOwner) {
        super.onStop(owner)
        isAppForeground = false
    }

    companion object {

        @JvmStatic
        var isAppForeground = false
    }
}