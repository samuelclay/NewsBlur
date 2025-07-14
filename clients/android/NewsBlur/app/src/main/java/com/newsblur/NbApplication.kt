package com.newsblur

import android.app.Application
import android.os.StrictMode
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
import com.newsblur.util.PrefConstants
import dagger.hilt.android.HiltAndroidApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Provider

@HiltAndroidApp
class NbApplication : Application(), DefaultLifecycleObserver {

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