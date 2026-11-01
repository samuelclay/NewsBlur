package com.newsblur.listen

import com.google.gson.JsonElement
import com.google.gson.JsonObject

/**
 * One entry in the web media player's shared queue or history (apps/media_player). Listen adds "listen" entries;
 * the web can also queue podcasts and videos, which Android never shows or plays but always keeps in place.
 */
data class ListenQueueItem(
    val storyHash: String,
    val mediaUrl: String,
    val mediaType: String,
    val title: String,
    val feedId: String?,
    val imageUrl: String?,
) {
    val isListen: Boolean
        get() = mediaType == ListenUpNextQueue.MEDIA_TYPE_LISTEN

    fun isSameEntry(other: ListenQueueItem): Boolean = storyHash == other.storyHash && mediaUrl == other.mediaUrl
}

/** GET /media_player/playback_state, cut down to what Listen uses. */
data class ListenPlaybackState(
    val queue: List<ListenQueueItem> = emptyList(),
    val history: List<ListenQueueItem> = emptyList(),
)

/**
 * ListenUpNext.kt keeps Up Next's rules in one place: the queue is shared with the web and iOS, Android shows only
 * its Listen entries, and a reorder always sends back the whole queue because the server drops whatever isn't
 * listed (apps/media_player/models.py reorder_queue).
 */
object ListenUpNextQueue {
    const val MEDIA_TYPE_LISTEN = "listen"

    fun mediaUrl(storyHash: String): String = "/listen/story/$storyHash"

    fun listenItems(queue: List<ListenQueueItem>): List<ListenQueueItem> = queue.filter { it.isListen }

    fun isQueued(
        queue: List<ListenQueueItem>,
        storyHash: String?,
    ): Boolean = storyHash != null && queue.any { it.isListen && it.storyHash == storyHash }

    /** Where a story sits in Up Next as people see it, counting only Listen entries: 1 for first. */
    fun positionOf(
        queue: List<ListenQueueItem>,
        storyHash: String,
    ): Int? =
        listenItems(queue)
            .indexOfFirst { it.storyHash == storyHash }
            .takeIf { it >= 0 }
            ?.plus(1)

    /** Adds to the end, as the server does, replacing an older copy of the same entry. */
    fun appended(
        queue: List<ListenQueueItem>,
        item: ListenQueueItem,
    ): List<ListenQueueItem> = queue.filterNot { it.isSameEntry(item) } + item

    fun without(
        queue: List<ListenQueueItem>,
        storyHash: String,
    ): List<ListenQueueItem> = queue.filterNot { it.isListen && it.storyHash == storyHash }

    /** The Listen entry that plays when the current story ends. */
    fun next(queue: List<ListenQueueItem>): ListenQueueItem? = listenItems(queue).firstOrNull()

    /**
     * The whole queue with its Listen entries in a new order. Other entries keep their slots, so a podcast queued
     * on the web stays exactly where it was. Listen entries missing from the order keep their relative order after
     * the ones that were named.
     */
    fun withListenOrder(
        queue: List<ListenQueueItem>,
        orderedStoryHashes: List<String>,
    ): List<ListenQueueItem> {
        val listen = listenItems(queue)
        val byHash = listen.associateBy { it.storyHash }
        val named = orderedStoryHashes.distinct().mapNotNull { byHash[it] }
        val ordered = named + listen.filterNot { it in named }
        val next = ordered.iterator()
        return queue.map { if (it.isListen) next.next() else it }
    }

    /** Moves the Listen entry at from to to, both counted among Listen entries as Up Next shows them. */
    fun moved(
        queue: List<ListenQueueItem>,
        from: Int,
        to: Int,
    ): List<ListenQueueItem> {
        val hashes = listenItems(queue).map { it.storyHash }.toMutableList()
        if (from !in hashes.indices || to !in hashes.indices || from == to) return queue
        hashes.add(to, hashes.removeAt(from))
        return withListenOrder(queue, hashes)
    }

    /** The queue_order the server's reorder expects: every entry, Listen or not, as story_hash and media_url. */
    fun reorderPayload(queue: List<ListenQueueItem>): List<Map<String, String>> =
        queue.map { mapOf("story_hash" to it.storyHash, "media_url" to it.mediaUrl) }

    /**
     * Reads the playback_state of a /media_player response; null playback_state means nothing has been queued yet.
     * Returns null only when the response isn't a playback state at all.
     */
    fun parseResponse(response: JsonObject?): ListenPlaybackState? {
        if (response == null || !response.has(KEY_PLAYBACK_STATE)) return null
        val state = response.get(KEY_PLAYBACK_STATE)
        if (state == null || state.isJsonNull) return ListenPlaybackState()
        if (!state.isJsonObject) return null
        val body = state.asJsonObject
        return ListenPlaybackState(
            queue = parseItems(body.get(KEY_QUEUE)),
            history = parseItems(body.get(KEY_HISTORY)),
        )
    }

    private fun parseItems(element: JsonElement?): List<ListenQueueItem> {
        if (element == null || !element.isJsonArray) return emptyList()
        return element.asJsonArray.mapNotNull { entry ->
            val item = entry.takeIf { it.isJsonObject }?.asJsonObject ?: return@mapNotNull null
            val storyHash = item.string("story_hash").orEmpty()
            val mediaUrl = item.string("media_url").orEmpty()
            if (storyHash.isEmpty() && mediaUrl.isEmpty()) return@mapNotNull null
            ListenQueueItem(
                storyHash = storyHash,
                mediaUrl = mediaUrl,
                mediaType = item.string("media_type").orEmpty(),
                title = item.string("media_title").orEmpty(),
                feedId = item.string("feed_id")?.takeIf { it.isNotEmpty() && it != "0" },
                imageUrl = item.string("image_url")?.takeIf { it.isNotEmpty() },
            )
        }
    }

    /** feed_id arrives as a number from the server but as a string from older clients. */
    private fun JsonObject.string(key: String): String? {
        val value = get(key)?.takeIf { it.isJsonPrimitive }?.asJsonPrimitive ?: return null
        return if (value.isNumber) value.asLong.toString() else value.asString
    }

    private const val KEY_PLAYBACK_STATE = "playback_state"
    private const val KEY_QUEUE = "queue"
    private const val KEY_HISTORY = "history"
}
