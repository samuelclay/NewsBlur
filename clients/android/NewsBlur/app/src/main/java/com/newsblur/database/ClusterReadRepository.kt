package com.newsblur.database

import com.newsblur.domain.Story
import com.newsblur.util.FeedSet

/** ClusterReadRepository.kt reconciles one batch while BlurDatabaseHelper holds its transaction. */
class ClusterReadRepository(private val backend: Backend) {
    data class State(val feedId: String, val score: Int, val read: Boolean, val socialIds: Set<String> = emptySet())

    interface Backend {
        fun storedStory(hash: String): State?
        fun localReadState(hash: String): Boolean?
        fun localReadChangedAt(hash: String): Long?
        fun pendingReadStateHashes(): Set<String> = emptySet()
        fun parentsReferencing(hashes: Set<String>): Map<String, Array<Story.ClusterStory>>
        fun setLocalReadState(hash: String, read: Boolean, changedAt: Long)
        fun setStoredReadState(hash: String, read: Boolean)
        fun setParentClusters(hash: String, children: Array<Story.ClusterStory>)
        fun adjustCounts(state: State, delta: Int)
    }

    fun reconcileServerReadState(hashes: Collection<String>, read: Boolean, requestStartedAt: Long) {
        val pending = backend.pendingReadStateHashes()
        val accepted = hashes.filter { it !in pending && (backend.localReadChangedAt(it) ?: Long.MIN_VALUE) <= requestStartedAt }
        apply(accepted, read, false)
    }

    fun applyBulkRead(hashes: Collection<String>, actionTime: Long) {
        apply(hashes, true, false, actionTime)
    }

    fun apply(hashes: Collection<String>, read: Boolean, adjustCounts: Boolean, actionTime: Long? = null): Set<FeedSet> {
        val unique = hashes.filter {
            it.isNotBlank() && (actionTime == null || (backend.localReadChangedAt(it) ?: Long.MIN_VALUE) <= actionTime || backend.localReadState(it) == read)
        }.toSet()
        val parents = backend.parentsReferencing(unique)
        val embedded = parents.values.flatMap { it.toList() }.groupBy { it.storyHash }
        val impacted = mutableSetOf<FeedSet>()
        for (hash in unique) {
            val state = backend.storedStory(hash) ?: embedded[hash]?.let { copies ->
                val child = copies.first()
                State(child.feedId, child.score, copies.any { it.read })
            }
            val previousRead = backend.localReadState(hash) ?: state?.read
            val feedId = state?.feedId ?: hash.substringBefore(':', "")
            if (feedId.isNotBlank()) impacted.add(FeedSet.singleFeed(feedId))
            if (!state?.socialIds.isNullOrEmpty()) impacted.add(FeedSet.multipleSocialFeeds(state!!.socialIds))
            if (adjustCounts && state != null && previousRead != null && previousRead != read && state.score >= 0) {
                backend.adjustCounts(state, if (read) -1 else 1)
            }
            // ReadingAction.kt replays the original intent; replay time must not supersede later actions.
            val changedAt = maxOf(actionTime ?: System.currentTimeMillis(), backend.localReadChangedAt(hash) ?: Long.MIN_VALUE)
            backend.setLocalReadState(hash, read, changedAt)
            backend.setStoredReadState(hash, read)
        }
        for ((parentHash, children) in parents) {
            if (children.none { it.storyHash in unique && it.read != read }) continue
            backend.setParentClusters(parentHash, children.map {
                if (it.storyHash in unique && it.read != read) copyWithReadState(it, read) else it
            }.toTypedArray())
        }
        return impacted
    }

    companion object {
        fun copyWithReadState(child: Story.ClusterStory, read: Boolean) = Story.ClusterStory().also {
            it.feedId = child.feedId
            it.storyHash = child.storyHash
            it.title = child.title
            it.timestamp = child.timestamp
            it.authors = child.authors
            it.score = child.score
            it.clusterTier = child.clusterTier
            it.read = read
            it.imageUrls = child.imageUrls
            it.secureImageThumbnails = child.secureImageThumbnails
        }
    }
}
