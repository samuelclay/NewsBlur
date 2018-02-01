package com.newsblur.service;

import android.util.Log;

import com.newsblur.util.FileCache;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;

public class CleanupService extends SubService {

    private static volatile boolean Running = false;

    public CleanupService(NBSyncService parent) {
        super(parent);
    }

    @Override
    protected void exec() {
        gotWork();

        if (PrefsUtils.isTimeToCleanup(parent)) {
            com.newsblur.util.Log.d(this.getClass().getName(), "cleaning up old stories");
            parent.dbHelper.cleanupVeryOldStories();
            if (!PrefsUtils.isKeepOldStories(parent)) {
                parent.dbHelper.cleanupReadStories();
            }
            PrefsUtils.updateLastCleanupTime(parent);
        }

        com.newsblur.util.Log.d(this.getClass().getName(), "cleaning up old story texts");
        parent.dbHelper.cleanupStoryText();

        com.newsblur.util.Log.d(this.getClass().getName(), "cleaning up notification dismissals");
        parent.dbHelper.cleanupDismissals();

        com.newsblur.util.Log.d(this.getClass().getName(), "cleaning up story image cache");
        FileCache imageCache = FileCache.asStoryImageCache(parent);
        imageCache.cleanupUnusedAndOld(parent.dbHelper.getAllStoryImages(), PrefsUtils.getMaxCachedAgeMillis(parent));

        com.newsblur.util.Log.d(this.getClass().getName(), "cleaning up icon cache");
        FileCache iconCache = FileCache.asIconCache(parent);
        iconCache.cleanupOld(PrefConstants.CACHE_AGE_VALUE_30D);

        com.newsblur.util.Log.d(this.getClass().getName(), "cleaning up thumbnail cache");
        FileCache thumbCache = FileCache.asThumbnailCache(parent);
        thumbCache.cleanupUnusedAndOld(parent.dbHelper.getAllStoryThumbnails(), PrefsUtils.getMaxCachedAgeMillis(parent));
    }

    public static boolean running() {
        return Running;
    }
    @Override
    protected void setRunning(boolean running) {
        Running = running;
    }
    @Override
    protected boolean isRunning() {
        return Running;
    }

}
        
