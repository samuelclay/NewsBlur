package com.newsblur.service;

import android.util.Log;

import com.newsblur.util.AppConstants;
import com.newsblur.util.FileCache;
import com.newsblur.util.PrefsUtils;

public class CleanupService extends SubService {

    private static volatile boolean Running = false;

    public CleanupService(NBSyncService parent) {
        super(parent);
    }

    @Override
    protected void exec() {
        if (!PrefsUtils.isTimeToCleanup(parent)) return;

        gotWork();

        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "cleaning up old stories");
        parent.dbHelper.cleanupVeryOldStories();
        if (!PrefsUtils.isKeepOldStories(parent)) {
            parent.dbHelper.cleanupReadStories();
        }

        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "cleaning up old story texts");
        parent.dbHelper.cleanupStoryText();

        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "cleaning up story image cache");
        FileCache imageCache = FileCache.asStoryImageCache(parent);
        imageCache.cleanupUnusedOrOld(parent.dbHelper.getAllStoryImages());

        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "cleaning up icon cache");
        FileCache iconCache = FileCache.asIconCache(parent);
        iconCache.cleanupOld();

        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "cleaning up thumbnail cache");
        FileCache thumbCache = FileCache.asThumbnailCache(parent);
        thumbCache.cleanupUnusedOrOld(parent.dbHelper.getAllStoryThumbnails());

        PrefsUtils.updateLastCleanupTime(parent);
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
        
