package com.newsblur.service;

import android.util.Log;

import com.newsblur.util.ImageCache;
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

        // do cleanup
        parent.dbHelper.cleanupVeryOldStories();
        if (!PrefsUtils.isKeepOldStories(parent)) {
            parent.dbHelper.cleanupReadStories();
        }
        parent.dbHelper.cleanupStoryText();
        ImageCache imageCache = new ImageCache(parent);
        imageCache.cleanup(parent.dbHelper.getAllStoryImages());

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
        
