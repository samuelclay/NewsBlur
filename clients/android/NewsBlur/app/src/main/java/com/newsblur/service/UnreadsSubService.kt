package com.newsblur.service

import com.newsblur.util.AppConstants
import com.newsblur.util.FeedUtils.Companion.inferFeedId
import com.newsblur.util.Log
import com.newsblur.util.StoryOrder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import java.util.Collections
import java.util.concurrent.ConcurrentLinkedQueue

class UnreadsSubService(delegate: SyncServiceDelegate) : SyncSubService(delegate) {

    private val doMeta = java.util.concurrent.atomic.AtomicBoolean(false)
    val isDoMetadata: Boolean get() = doMeta.get()

    override suspend fun execute() = coroutineScope {
        try {
            ensureActive()
            setServiceState(ServiceState.UnreadsSync)

            if (doMeta.getAndSet(false)) {
                syncUnreadList()
            }

            ensureActive()
            if (storyHashQueue.isNotEmpty()) {
                getNewUnreadStories(this)
                pushNotifications()
            }
        } finally {
            setServiceStateIdleIf(ServiceState.UnreadsSync)
        }
    }

    private suspend fun syncUnreadList() {
        currentCoroutineContext().ensureActive()
        // get unread hashes and dates from the API
        val unreadHashes = storyApi.getUnreadStoryHashes()

        currentCoroutineContext().ensureActive()

        // get all the stories we thought were unread before. we should not enqueue a fetch of
        // stories we already have.  also, if any existing unreads fail to appear in
        // the set of unreads from the API, we will mark them as read. note that this collection
        // will be searched many times for new unreads, so it should be a Set, not a List.
        val oldUnreadHashes = dbHelper.getUnreadStoryHashesAsSet()
        Log.i(this, "starting unread count: " + oldUnreadHashes.size)

        // a place to store and then sort unread hashes we aim to fetch. note the member format
        // is made to match the format of the API response (a list of [hash, date] tuples). it
        // is crucial that we re-use objects as much as possible to avoid memory churn
        val sortationList: MutableList<Array<String>> = ArrayList()

        // process the api response, both bookkeeping no-longer-unread stories and populating
        // the sortation list we will use to create the fetch list for step two
        var count = 0
        feedLoop@ for (entry in unreadHashes.unreadHashes.entries) {
            // the API gives us a list of unreads, split up by feed ID. the unreads are tuples of
            // story hash and date
            val feedId = entry.key
            // ignore unreads from orphaned feeds
            if (delegate.isOrphanFeed(feedId)) continue@feedLoop
            // ignore unreads from disabled feeds
            if (delegate.isDisabledFeed(feedId)) continue@feedLoop
            for (newUnread in entry.value) {
                // only fetch the reported unreads if we don't already have them
                if (!oldUnreadHashes.contains(newUnread[0])) {
                    sortationList.add(newUnread)
                } else {
                    oldUnreadHashes.remove(newUnread[0])
                }
                count++
            }
        }
        Log.i(this, "new unread count: $count")
        Log.i(this, "new unreads found: ${sortationList.size}")
        Log.i(this, "unreads to retire: ${oldUnreadHashes.size}")

        // any stories that we previously thought to be unread but were not found in the
        // list, mark them read now
        dbHelper.markStoryHashesRead(oldUnreadHashes)

        currentCoroutineContext().ensureActive()

        // now sort the unreads we need to fetch so they are fetched roughly in the order
        // the user is likely to read them.  if the user reads newest first, those come first.
        val sortNewest = (prefsRepo.getDefaultStoryOrder() == StoryOrder.NEWEST)
        // custom comparator that understands to sort tuples by the value of the second element
        val hashSorter: Comparator<Array<String>> = object : Comparator<Array<String>> {
            override fun compare(lhs: Array<String>, rhs: Array<String>): Int {
                // element [1] of the unread tuple is the date in epoch seconds
                return if (sortNewest) {
                    rhs[1].compareTo(lhs[1])
                } else {
                    lhs[1].compareTo(rhs[1])
                }
            }

            override fun equals(other: Any?): Boolean {
                return false
            }
        }
        Collections.sort(sortationList, hashSorter)

        // now that we have the sorted set of hashes, turn them into a list over which we
        // can iterate to fetch them
        storyHashQueue.clear()
        for (tuple in sortationList) {
            // element [0] of the tuple is the story hash, the rest can safely be thown out
            storyHashQueue.add(tuple[0])
        }
    }

    private suspend fun getNewUnreadStories(scope: CoroutineScope) {
        val notifyFeeds = dbHelper.getNotifyFeeds()
        unreadSyncLoop@ while (storyHashQueue.isNotEmpty()) {
            currentCoroutineContext().ensureActive()
            val isOfflineEnabled = prefsRepo.isOfflineEnabled()
            val isEnableNotifications = prefsRepo.isEnableNotifications()
            if (!(isOfflineEnabled || isEnableNotifications)) return

            val hashBatch: MutableList<String> = ArrayList(AppConstants.UNREAD_FETCH_BATCH_SIZE)
            val hashSkips: MutableList<String> = ArrayList(AppConstants.UNREAD_FETCH_BATCH_SIZE)
            batchLoop@ for (hash in storyHashQueue) {
                if (isOfflineEnabled || notifyFeeds.contains(inferFeedId(hash))) {
                    hashBatch.add(hash)
                } else {
                    hashSkips.add(hash)
                }
                if (hashBatch.size >= AppConstants.UNREAD_FETCH_BATCH_SIZE) break@batchLoop
            }

            currentCoroutineContext().ensureActive()
            val response = storyApi.getStoriesByHash(hashBatch)
            if (!SyncServiceUtil.isStoryResponseGood(response)) {
                Log.e(this, "error fetching unreads batch, abandoning sync.")
                break@unreadSyncLoop
            }

            val stateFilter = prefsRepo.getStateFilter()
            insertStories(response!!, stateFilter)
            for (hash in hashBatch) {
                storyHashQueue.remove(hash)
            }
            for (hash in hashSkips) {
                storyHashQueue.remove(hash)
            }

            prefetchImages(response, scope)
        }
    }

    fun doMetadata() {
        doMeta.set(true)
    }

    companion object {

        /** Unread story hashes the API listed that we do not appear to have locally yet.  */
        var storyHashQueue = ConcurrentLinkedQueue<String>()

        /**
         * Describe the number of unreads left to be synced or return an empty message (space padded).
         */
        val pendingCount: String
            get() {
                val c: Int = storyHashQueue.size
                return if (c < 1) " " else " $c "
            }

        fun clear() {
            storyHashQueue.clear()
        }
    }
}