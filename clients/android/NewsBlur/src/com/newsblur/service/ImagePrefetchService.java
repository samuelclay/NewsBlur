package com.newsblur.service;

import android.util.Log;

import com.newsblur.domain.Story;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.network.domain.UnreadStoryHashesResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ImageCache;
import com.newsblur.util.PrefsUtils;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map.Entry;
import java.util.Set;

public class ImagePrefetchService extends SubService {

    private static volatile boolean Running = false;

    private ImageCache imageCache;

    /** URLs of images contained in recently fetched stories that are candidates for prefetch. */
    static Set<String> ImageQueue;
    static { ImageQueue = new HashSet<String>(); }

    public ImagePrefetchService(NBSyncService parent) {
        super(parent);
        imageCache = new ImageCache(parent);
    }

    @Override
    protected void exec() {
        if (!PrefsUtils.isImagePrefetchEnabled(parent)) return;
        if (ImageQueue.size() < 1) return;

        gotWork();

        while ((ImageQueue.size() > 0) && PrefsUtils.isImagePrefetchEnabled(parent)) {
            startExpensiveCycle();
            Set<String> fetchedImages = new HashSet<String>();
            Set<String> batch = new HashSet<String>(AppConstants.IMAGE_PREFETCH_BATCH_SIZE);
            batchloop: for (String url : ImageQueue) {
                batch.add(url);
                if (batch.size() >= AppConstants.IMAGE_PREFETCH_BATCH_SIZE) break batchloop;
            }
            try {
                for (String url : batch) {
                    if (parent.stopSync()) return;
                    
                    if (AppConstants.VERBOSE_LOG) Log.d(this.getClass().getName(), "prefetching image: " + url);
                    imageCache.cacheImage(url);

                    fetchedImages.add(url);
                }
            } finally {
                ImageQueue.removeAll(fetchedImages);
                gotWork();
            }
        }
        // TODO: do this in a cleanup thread
        imageCache.cleanup();
    }

    public void addUrl(String url) {
        ImageQueue.add(url);
    }

    public static int  getPendingCount() {
        return ImageQueue.size();
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
        
