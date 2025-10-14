package com.newsblur.service

import com.newsblur.util.Log
import com.newsblur.util.PrefConstants

class CleanupSubService(
    delegate: SyncServiceDelegate,
) : SyncSubService(delegate) {
    override suspend fun execute() {
        if (!prefsRepo.isTimeToCleanup()) return

        setServiceState(ServiceState.CleanupSync)

        Log.d(this.javaClass.name, "cleaning up old stories")
        dbHelper.cleanupVeryOldStories()
        if (!prefsRepo.isKeepOldStories()) {
            dbHelper.cleanupReadStories()
        }
        prefsRepo.updateLastCleanupTime()

        Log.d(this.javaClass.name, "cleaning up old story texts")
        dbHelper.cleanupStoryText()

        Log.d(this.javaClass.name, "cleaning up notification dismissals")
        dbHelper.cleanupDismissals()

        Log.d(this.javaClass.name, "cleaning up story image cache")
        storyImageCache.cleanupUnusedAndOld(
            dbHelper.getAllStoryImages(),
            prefsRepo.getMaxCachedAgeMillis(),
        )

        Log.d(this.javaClass.name, "cleaning up icon cache")
        iconCache.cleanupOld(PrefConstants.CACHE_AGE_VALUE_30D)

        Log.d(this.javaClass.name, "cleaning up thumbnail cache")
        thumbnailCache.cleanupUnusedAndOld(
            dbHelper.getAllStoryThumbnails(),
            prefsRepo.getMaxCachedAgeMillis(),
        )

        setServiceStateIdleIf(ServiceState.CleanupSync)
    }
}
