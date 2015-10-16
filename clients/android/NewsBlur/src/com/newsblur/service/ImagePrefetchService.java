package com.newsblur.service;

import android.util.Log;

import com.newsblur.util.AppConstants;
import com.newsblur.util.ImageCache;
import com.newsblur.util.PrefsUtils;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

public class ImagePrefetchService extends SubService {

    private static volatile boolean Running = false;

    ImageCache imageCache;

    /** URLs of images contained in recently fetched stories that are candidates for prefetch. */
    static Set<String> ImageQueue;
    static { ImageQueue = Collections.synchronizedSet(new HashSet<String>()); }

    public ImagePrefetchService(NBSyncService parent) {
        super(parent);
        imageCache = new ImageCache(parent);
    }

    @Override
    protected void exec() {
        if (!PrefsUtils.isImagePrefetchEnabled(parent)) return;
        if (ImageQueue.size() < 1) return;
        if (!PrefsUtils.isBackgroundNetworkAllowed(parent)) return;

        gotWork();

        while (ImageQueue.size() > 0) {
            if (! PrefsUtils.isImagePrefetchEnabled(parent)) return;
            if (! PrefsUtils.isBackgroundNetworkAllowed(parent)) return;

            startExpensiveCycle();
            // on each batch, re-query the DB for images associated with yet-unread stories
            // this is a bit expensive, but we are running totally async at a really low priority
            Set<String> unreadImages = parent.dbHelper.getAllStoryImages();
            Set<String> fetchedImages = new HashSet<String>();
            Set<String> batch = new HashSet<String>(AppConstants.IMAGE_PREFETCH_BATCH_SIZE);
            batchloop: for (String url : ImageQueue) {
                batch.add(url);
                if (batch.size() >= AppConstants.IMAGE_PREFETCH_BATCH_SIZE) break batchloop;
            }
            try {
                for (String url : batch) {
                    if (parent.stopSync()) return;
                    // dont fetch the image if the associated story was marked read before we got to it
                    if (unreadImages.contains(url)) {
                        if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "prefetching image: " + url);
                        imageCache.cacheImage(url);
                    }
                    fetchedImages.add(url);
                }
            } finally {
                ImageQueue.removeAll(fetchedImages);
                gotWork();
            }
        }
        
    }

    public void addUrl(String url) {
        ImageQueue.add(url);
    }

    public static int  getPendingCount() {
        return ImageQueue.size();
    }

    public static void clear() {
        ImageQueue.clear();
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
        
