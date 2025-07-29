package com.newsblur.service

import com.newsblur.util.AppConstants
import com.newsblur.util.Log
import com.newsblur.util.NBScope
import java.util.Collections

class ImagePrefetchService(parent: NBSyncService) : SubService(parent, NBScope) {

    override fun exec() {
        activelyRunning = true
        try {
            if (!parent.prefsRepo.isImagePrefetchEnabled()) return
            if (!parent.prefsRepo.isBackgroundNetworkAllowed(parent)) return

            while (StoryImageQueue.isNotEmpty()) {
                if (!parent.prefsRepo.isImagePrefetchEnabled()) return
                if (!parent.prefsRepo.isBackgroundNetworkAllowed(parent)) return

                Log.d(this, "story images to prefetch: " + StoryImageQueue.size)
                // on each batch, re-query the DB for images associated with yet-unread stories
                // this is a bit expensive, but we are running totally async at a really low priority
                val unreadImages = parent.dbHelper.getAllStoryImages()
                val fetchedImages: MutableSet<String> = HashSet()
                val batch: MutableSet<String> = HashSet(AppConstants.IMAGE_PREFETCH_BATCH_SIZE)
                batchLoop@ for (url in StoryImageQueue) {
                    batch.add(url)
                    if (batch.size >= AppConstants.IMAGE_PREFETCH_BATCH_SIZE) break@batchLoop
                }
                try {
                    fetchLoop@ for (url in batch) {
                        if (parent.stopSync()) break@fetchLoop
                        // don't fetch the image if the associated story was marked read before we got to it
                        if (unreadImages.contains(url)) {
                            if (AppConstants.VERBOSE_LOG) android.util.Log.d(this.javaClass.name, "prefetching image: $url")
                            parent.storyImageCache.cacheFile(url)
                        }
                        fetchedImages.add(url)
                    }
                } finally {
                    StoryImageQueue.removeAll(fetchedImages)
                    Log.d(this, "story images fetched: ${fetchedImages.size}")
                }
            }

            if (parent.stopSync()) return

            while (ThumbnailQueue.isNotEmpty()) {
                if (!parent.prefsRepo.isImagePrefetchEnabled()) return
                if (!parent.prefsRepo.isBackgroundNetworkAllowed(parent)) return

                Log.d(this, "story thumbs to prefetch: " + StoryImageQueue.size)
                // on each batch, re-query the DB for images associated with yet-unread stories
                // this is a bit expensive, but we are running totally async at a really low priority
                val unreadImages = parent.dbHelper.getAllStoryThumbnails()
                val fetchedImages: MutableSet<String> = HashSet()
                val batch: MutableSet<String> = HashSet(AppConstants.IMAGE_PREFETCH_BATCH_SIZE)
                batchLoop@ for (url in ThumbnailQueue) {
                    batch.add(url)
                    if (batch.size >= AppConstants.IMAGE_PREFETCH_BATCH_SIZE) break@batchLoop
                }
                try {
                    fetchLoop@ for (url in batch) {
                        if (parent.stopSync()) break@fetchLoop
                        // don't fetch the image if the associated story was marked read before we got to it
                        if (unreadImages.contains(url)) {
                            if (AppConstants.VERBOSE_LOG) android.util.Log.d(this.javaClass.name, "prefetching thumbnail: $url")
                            parent.thumbnailCache.cacheFile(url)
                        }
                        fetchedImages.add(url)
                    }
                } finally {
                    ThumbnailQueue.removeAll(fetchedImages)
                    Log.d(this, "story thumbs fetched: " + fetchedImages.size)
                }
            }
        } finally {
            activelyRunning = false
        }
    }

    fun addUrl(url: String?) {
        url?.let { StoryImageQueue.add(it) }
    }

    fun addThumbnailUrl(url: String?) {
        url?.let { ThumbnailQueue.add(it) }
    }

    companion object {

        @JvmField
        var activelyRunning: Boolean = false

        /** URLs of images contained in recently fetched stories that are candidates for prefetch.  */
        var StoryImageQueue: MutableSet<String> = Collections.synchronizedSet(HashSet<String>())

        /** URLs of thumbnails for recently fetched stories that are candidates for prefetch.  */
        var ThumbnailQueue: MutableSet<String> = Collections.synchronizedSet(HashSet<String>())

        @JvmStatic
        val pendingCount: Int
            get() = (StoryImageQueue.size + ThumbnailQueue.size)

        @JvmStatic
        fun clear() {
            StoryImageQueue.clear()
            ThumbnailQueue.clear()
        }
    }
}

