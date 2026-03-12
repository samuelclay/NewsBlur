package com.newsblur

import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.preference.PreferenceManager
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.di.IconFileCache
import com.newsblur.di.StoryImageCache
import com.newsblur.di.ThumbnailCache
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.FileCache
import com.newsblur.util.Log
import com.newsblur.util.ReadTimeTracker
import dagger.hilt.android.HiltAndroidApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Provider

@HiltAndroidApp
class NbApplication :
    Application(),
    DefaultLifecycleObserver {
    @Inject
    @IconFileCache
    lateinit var iconCacheProvider: Provider<FileCache>

    @Inject
    @ThumbnailCache
    lateinit var thumbnailCacheProvider: Provider<FileCache>

    @Inject
    @StoryImageCache
    lateinit var storyImageCacheProvider: Provider<FileCache>

    @Inject
    lateinit var prefsRepo: Provider<PrefsRepo>

    @Inject
    lateinit var dbHelper: Provider<BlurDatabaseHelper>

    @Inject
    lateinit var readTimeTracker: Provider<ReadTimeTracker>

    override fun onCreate() {
        super<Application>.onCreate()
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)
        Log.offerContext(this)

        // warm up most of the dependencies that would block the UI thread
        CoroutineScope(Dispatchers.IO).launch {
            dbHelper.get()
            prefsRepo.get()
            iconCacheProvider.get()
            thumbnailCacheProvider.get()
            storyImageCacheProvider.get()

            PreferenceManager.setDefaultValues(
                this@NbApplication,
                R.xml.activity_settings,
                false,
            )
        }

        if (BuildConfig.DEBUG) {
//            StrictMode.setVmPolicy(
//                    StrictMode.VmPolicy.Builder()
//                            .detectLeakedSqlLiteObjects()
//                            .detectLeakedClosableObjects()
//                            .penaltyLog()
//                            .penaltyDeath()
//                            .build()
//            )

//            StrictMode.setThreadPolicy(
//                    StrictMode.ThreadPolicy.Builder()
//                            .detectDiskReads()
//                            .detectDiskWrites()
//                            .penaltyLog()
//                            .build()
//            )
        }
    }

    override fun onStart(owner: LifecycleOwner) {
        super.onStart(owner)
        isAppForeground = true
        readTimeTracker.get().isAppActive = true
        readTimeTracker.get().resumeFromBackground()
    }

    override fun onStop(owner: LifecycleOwner) {
        super.onStop(owner)
        isAppForeground = false
        readTimeTracker.get().isAppActive = false
        readTimeTracker.get().harvestForBackground()
    }

    companion object {
        @JvmStatic
        var isAppForeground = false

        @JvmStatic
        fun getVersion(context: Context): String? {
            try {
                return context.packageManager.getPackageInfo(context.packageName, 0).versionName
            } catch (_: PackageManager.NameNotFoundException) {
                android.util.Log.w(PrefsRepo::class.java.name, "could not determine app version")
                return null
            }
        }
    }
}
