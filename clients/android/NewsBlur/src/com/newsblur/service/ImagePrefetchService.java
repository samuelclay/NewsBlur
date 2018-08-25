package com.newsblur.service;

import android.util.Log;

import com.newsblur.util.AppConstants;
import com.newsblur.util.FileCache;
import com.newsblur.util.PrefsUtils;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

public class ImagePrefetchService extends SubService {

    public static boolean activelyRunning = false;

    FileCache storyImageCache;
    FileCache thumbnailCache;

    /** URLs of images contained in recently fetched stories that are candidates for prefetch. */
    static Set<String> StoryImageQueue;
    static { StoryImageQueue = Collections.synchronizedSet(new HashSet<String>()); }
    /** URLs of thumbnails for recently fetched stories that are candidates for prefetch. */
    static Set<String> ThumbnailQueue;
    static { ThumbnailQueue = Collections.synchronizedSet(new HashSet<String>()); }

    public ImagePrefetchService(NBSyncService parent) {
        super(parent);
        storyImageCache = FileCache.asStoryImageCache(parent);
        thumbnailCache = FileCache.asThumbnailCache(parent);
        thumbnailCache.addChain(storyImageCache);
    }

    @Override
    protected void exec() {
        activelyRunning = true;
        try {
            if (!PrefsUtils.isImagePrefetchEnabled(parent)) return;
            if (!PrefsUtils.isBackgroundNetworkAllowed(parent)) return;

            while (StoryImageQueue.size() > 0) {
                if (! PrefsUtils.isImagePrefetchEnabled(parent)) return;
                if (! PrefsUtils.isBackgroundNetworkAllowed(parent)) return;

                startExpensiveCycle();
                com.newsblur.util.Log.d(this, "story images to prefetch: " + StoryImageQueue.size());
                // on each batch, re-query the DB for images associated with yet-unread stories
                // this is a bit expensive, but we are running totally async at a really low priority
                Set<String> unreadImages = parent.dbHelper.getAllStoryImages();
                Set<String> fetchedImages = new HashSet<String>();
                Set<String> batch = new HashSet<String>(AppConstants.IMAGE_PREFETCH_BATCH_SIZE);
                batchloop: for (String url : StoryImageQueue) {
                    batch.add(url);
                    if (batch.size() >= AppConstants.IMAGE_PREFETCH_BATCH_SIZE) break batchloop;
                }
                try {
                    fetchloop: for (String url : batch) {
                        if (parent.stopSync()) break fetchloop;
                        // dont fetch the image if the associated story was marked read before we got to it
                        if (unreadImages.contains(url)) {
                            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "prefetching image: " + url);
                            storyImageCache.cacheFile(url);
                        }
                        fetchedImages.add(url);
                    }
                } finally {
                    StoryImageQueue.removeAll(fetchedImages);
                    com.newsblur.util.Log.d(this, "story images fetched: " + fetchedImages.size());
                }
            }

            if (parent.stopSync()) return;

            while (ThumbnailQueue.size() > 0) {
                if (! PrefsUtils.isImagePrefetchEnabled(parent)) return;
                if (! PrefsUtils.isBackgroundNetworkAllowed(parent)) return;

                startExpensiveCycle();
                com.newsblur.util.Log.d(this, "story thumbs to prefetch: " + StoryImageQueue.size());
                // on each batch, re-query the DB for images associated with yet-unread stories
                // this is a bit expensive, but we are running totally async at a really low priority
                Set<String> unreadImages = parent.dbHelper.getAllStoryThumbnails();
                Set<String> fetchedImages = new HashSet<String>();
                Set<String> batch = new HashSet<String>(AppConstants.IMAGE_PREFETCH_BATCH_SIZE);
                batchloop: for (String url : ThumbnailQueue) {
                    batch.add(url);
                    if (batch.size() >= AppConstants.IMAGE_PREFETCH_BATCH_SIZE) break batchloop;
                }
                try {
                    fetchloop: for (String url : batch) {
                        if (parent.stopSync()) break fetchloop;
                        // dont fetch the image if the associated story was marked read before we got to it
                        if (unreadImages.contains(url)) {
                            if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "prefetching thumbnail: " + url);
                            thumbnailCache.cacheFile(url);
                        }
                        fetchedImages.add(url);
                    }
                } finally {
                    ThumbnailQueue.removeAll(fetchedImages);
                    com.newsblur.util.Log.d(this, "story thumbs fetched: " + fetchedImages.size());
                }
            }
        } finally {
            activelyRunning = false;
        }
    }

    public void addUrl(String url) {
        StoryImageQueue.add(url);
    }

    public void addThumbnailUrl(String url) {
        ThumbnailQueue.add(url);
    }

    public static int getPendingCount() {
        return (StoryImageQueue.size() + ThumbnailQueue.size());
    }

    public static void clear() {
        StoryImageQueue.clear();
        ThumbnailQueue.clear();
    }

}
        
