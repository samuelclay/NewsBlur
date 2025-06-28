package com.newsblur

import android.app.Application
import android.os.StrictMode
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.preference.PreferenceManager
import com.newsblur.preference.PrefRepository
import com.newsblur.util.Log
import com.newsblur.util.PrefConstants
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class NbApplication : Application(), DefaultLifecycleObserver {

    @Inject
    lateinit var prefRepository: PrefRepository

    override fun onCreate() {
        super<Application>.onCreate()
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)
        Log.offerContext(this)

        // load SharedPreferences from disk
        getSharedPreferences(PrefConstants.PREFERENCES, 0)

        // load XML default and write any missing keys
        PreferenceManager.setDefaultValues(
                this@NbApplication,
                R.xml.activity_settings,
                false,
        )

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