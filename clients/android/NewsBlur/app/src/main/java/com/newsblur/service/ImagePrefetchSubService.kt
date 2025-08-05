package com.newsblur.service

import com.newsblur.util.AppConstants
import com.newsblur.util.Log
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.ensureActive
import java.util.concurrent.ConcurrentLinkedQueue

class ImagePrefetchSubService(delegate: SyncServiceDelegate) : SyncSubService(delegate) {

    override suspend fun execute() = coroutineScope {
        if (!prefsRepo.isImagePrefetchEnabled()) return@coroutineScope
        if (!prefsRepo.isBackgroundNetworkAllowed(context)) return@coroutineScope

        while (storyImageQueue.isNotEmpty()) {
            ensureActive()
            if (!prefsRepo.isImagePrefetchEnabled()) return@coroutineScope
            if (!prefsRepo.isBackgroundNetworkAllowed(context)) return@coroutineScope

            Log.d(this, "story images to prefetch: " + storyImageQueue.size)
            // on each batch, re-query the DB for images associated with yet-unread stories
            // this is a bit expensive, but we are running totally async at a really low priority
            val unreadImages = dbHelper.getAllStoryImages()
            val fetchedImages: MutableSet<String> = HashSet()
            val batch: MutableSet<String> = HashSet(AppConstants.IMAGE_PREFETCH_BATCH_SIZE)
            batchLoop@ for (url in storyImageQueue) {
                batch.add(url)
                if (batch.size >= AppConstants.IMAGE_PREFETCH_BATCH_SIZE) break@batchLoop
            }
            try {
                fetchLoop@ for (url in batch) {
                    ensureActive()
                    // don't fetch the image if the associated story was marked read before we got to it
                    if (unreadImages.contains(url)) {
                        if (AppConstants.VERBOSE_LOG) android.util.Log.d(this.javaClass.name, "prefetching image: $url")
                        storyImageCache.cacheFile(url)
                    }
                    fetchedImages.add(url)
                }
            } finally {
                storyImageQueue.removeAll(fetchedImages)
                Log.d(this, "story images fetched: ${fetchedImages.size}")
            }
        }

        ensureActive()

        while (thumbnailQueue.isNotEmpty()) {
            if (!prefsRepo.isImagePrefetchEnabled()) return@coroutineScope
            if (!prefsRepo.isBackgroundNetworkAllowed(context)) return@coroutineScope

            Log.d(this, "story thumbs to prefetch: " + thumbnailQueue.size)
            // on each batch, re-query the DB for images associated with yet-unread stories
            // this is a bit expensive, but we are running totally async at a really low priority
            val unreadImages = dbHelper.getAllStoryThumbnails()
            val fetchedImages: MutableSet<String> = HashSet()
            val batch: MutableSet<String> = HashSet(AppConstants.IMAGE_PREFETCH_BATCH_SIZE)
            batchLoop@ for (url in thumbnailQueue) {
                batch.add(url)
                if (batch.size >= AppConstants.IMAGE_PREFETCH_BATCH_SIZE) break@batchLoop
            }
            try {
                fetchLoop@ for (url in batch) {
                    ensureActive()
                    // don't fetch the image if the associated story was marked read before we got to it
                    if (unreadImages.contains(url)) {
                        if (AppConstants.VERBOSE_LOG) android.util.Log.d(this.javaClass.name, "prefetching thumbnail: $url")
                        thumbnailCache.cacheFile(url)
                    }
                    fetchedImages.add(url)
                }
            } finally {
                thumbnailQueue.removeAll(fetchedImages)
                Log.d(this, "story thumbs fetched: " + fetchedImages.size)
            }
        }
    }

    fun addStoryUrl(url: String?) {
        url?.let { storyImageQueue.add(it) }
    }

    fun addThumbnailUrl(url: String?) {
        url?.let { thumbnailQueue.add(it) }
    }

    companion object {


        /** URLs of images contained in recently fetched stories that are candidates for prefetch.  */
        private val storyImageQueue = ConcurrentLinkedQueue<String>()

        /** URLs of thumbnails for recently fetched stories that are candidates for prefetch.  */
        private val thumbnailQueue = ConcurrentLinkedQueue<String>()

        val pendingCount: Int
            get() = (storyImageQueue.size + thumbnailQueue.size)

        fun clear() {
            storyImageQueue.clear()
            thumbnailQueue.clear()
        }
    }
}