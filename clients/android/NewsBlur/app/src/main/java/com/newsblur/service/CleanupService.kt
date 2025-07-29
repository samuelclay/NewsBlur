package com.newsblur.service

import com.newsblur.util.Log
import com.newsblur.util.NBScope
import com.newsblur.util.PrefConstants

class CleanupService(parent: NBSyncService) : SubService(parent, NBScope) {

    override fun exec() {
        if (!parent.prefsRepo.isTimeToCleanup()) return

        activelyRunning = true

        Log.d(this.javaClass.name, "cleaning up old stories")
        parent.dbHelper.cleanupVeryOldStories()
        if (!parent.prefsRepo.isKeepOldStories()) {
            parent.dbHelper.cleanupReadStories()
        }
        parent.prefsRepo.updateLastCleanupTime()

        Log.d(this.javaClass.name, "cleaning up old story texts")
        parent.dbHelper.cleanupStoryText()

        Log.d(this.javaClass.name, "cleaning up notification dismissals")
        parent.dbHelper.cleanupDismissals()

        Log.d(this.javaClass.name, "cleaning up story image cache")
        parent.storyImageCache.cleanupUnusedAndOld(
                parent.dbHelper.getAllStoryImages(),
                parent.prefsRepo.getMaxCachedAgeMillis(),
        )

        Log.d(this.javaClass.name, "cleaning up icon cache")
        parent.iconCache.cleanupOld(PrefConstants.CACHE_AGE_VALUE_30D)

        Log.d(this.javaClass.name, "cleaning up thumbnail cache")
        parent.thumbnailCache.cleanupUnusedAndOld(
                parent.dbHelper.getAllStoryThumbnails(),
                parent.prefsRepo.getMaxCachedAgeMillis(),
        )

        activelyRunning = false
    }

    companion object {
        @JvmField
        var activelyRunning: Boolean = false
    }
}

