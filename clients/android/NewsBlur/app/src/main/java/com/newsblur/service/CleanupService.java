package com.newsblur.service;

import com.newsblur.util.ExtensionsKt;
import com.newsblur.util.PrefConstants;

public class CleanupService extends SubService {

    public static boolean activelyRunning = false;

    public CleanupService(NBSyncService parent) {
        super(parent, ExtensionsKt.NBScope);
    }

    @Override
    protected void exec() {

        if (!parent.prefRepository.isTimeToCleanup()) return;

        activelyRunning = true;

        com.newsblur.util.Log.d(this.getClass().getName(), "cleaning up old stories");
        parent.dbHelper.cleanupVeryOldStories();
        if (!parent.prefRepository.isKeepOldStories()) {
            parent.dbHelper.cleanupReadStories();
        }
        parent.prefRepository.updateLastCleanupTime();

        com.newsblur.util.Log.d(this.getClass().getName(), "cleaning up old story texts");
        parent.dbHelper.cleanupStoryText();

        com.newsblur.util.Log.d(this.getClass().getName(), "cleaning up notification dismissals");
        parent.dbHelper.cleanupDismissals();

        com.newsblur.util.Log.d(this.getClass().getName(), "cleaning up story image cache");
        parent.storyImageCache.cleanupUnusedAndOld(parent.dbHelper.getAllStoryImages(), parent.prefRepository.getMaxCachedAgeMillis());

        com.newsblur.util.Log.d(this.getClass().getName(), "cleaning up icon cache");
        parent.iconCache.cleanupOld(PrefConstants.CACHE_AGE_VALUE_30D);

        com.newsblur.util.Log.d(this.getClass().getName(), "cleaning up thumbnail cache");
        parent.thumbnailCache.cleanupUnusedAndOld(parent.dbHelper.getAllStoryThumbnails(), parent.prefRepository.getMaxCachedAgeMillis());

        activelyRunning = false;
    }
    
}
        
