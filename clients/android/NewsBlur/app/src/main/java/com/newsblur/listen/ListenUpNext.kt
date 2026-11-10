package com.newsblur.listen

import com.google.gson.JsonElement
import com.google.gson.JsonObject

/**
 * One entry in the web media player's shared queue or history (apps/media_player). Android plays "listen" entries
 * (stories read aloud) and "audio" entries (podcast episodes, ListenMedia.kt); the web can also queue videos, which
 * Android never shows or plays but always keeps in place.
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

    /** Whether Android plays this entry: a story read aloud or an audio file. */
    val isPlayable: Boolean
        get() = isListen || mediaType == ListenUpNextQueue.MEDIA_TYPE_AUDIO

    /** The server tells entries apart by story and media URL together (apps/media_player/models.py). */
    val entryId: String
        get() = ListenUpNextQueue.entryId(storyHash, mediaUrl)

    fun isSameEntry(other: ListenQueueItem): Boolean = storyHash == other.storyHash && mediaUrl == other.mediaUrl
}

/** A History entry, with where it stopped so it can be resumed (ListenMedia.kt's ListenMediaResume). */
data class ListenHistoryEntry(
    val item: ListenQueueItem,
    val positionSeconds: Double,
    val durationSeconds: Double,
)

/** GET /media_player/playback_state, cut down to what Listen and podcast playback use. */
data class ListenPlaybackState(
    val queue: List<ListenQueueItem> = emptyList(),
    val history: List<ListenHistoryEntry> = emptyList(),
    /** What the web, iOS or this app last played, with its saved position; null when nothing has played. */
    val current: ListenCurrentMedia? = null,
    val settings: ListenMediaSettings = ListenMediaSettings(),
    /** current_playback_rate: always the podcast and video rate, since the web keeps Listen's speed apart. */
    val mediaSpeed: Double? = null,
)

/**
 * ListenUpNext.kt keeps Up Next's rules in one place: the queue is shared with the web and iOS, Android shows only
 * the entries it can play, and a reorder always sends back the whole queue because the server drops whatever isn't
 * listed (apps/media_player/models.py reorder_queue).
 */
object ListenUpNextQueue {
    const val MEDIA_TYPE_LISTEN = "listen"
    const val MEDIA_TYPE_AUDIO = "audio"

    fun mediaUrl(storyHash: String): String = "/listen/story/$storyHash"

    fun entryId(
        storyHash: String,
        mediaUrl: String,
    ): String = "$storyHash\n$mediaUrl"

    fun listenItems(queue: List<ListenQueueItem>): List<ListenQueueItem> = queue.filter { it.isListen }

    /** The entries Up Next shows on Android, in play order. */
    fun playableItems(queue: List<ListenQueueItem>): List<ListenQueueItem> = queue.filter { it.isPlayable }

    /** Whether a story is queued to be read aloud; a podcast queued from the same story doesn't count. */
    fun isQueued(
        queue: List<ListenQueueItem>,
        storyHash: String?,
    ): Boolean = storyHash != null && queue.any { it.isListen && it.storyHash == storyHash }

    fun containsEntry(
        queue: List<ListenQueueItem>,
        entryId: String?,
    ): Boolean = entryId != null && queue.any { it.entryId == entryId }

    /** Where an entry sits in Up Next as people see it, counting only entries Android plays: 1 for first. */
    fun positionOf(
        queue: List<ListenQueueItem>,
        entryId: String,
    ): Int? =
        playableItems(queue)
            .indexOfFirst { it.entryId == entryId }
            .takeIf { it >= 0 }
            ?.plus(1)

    /** Adds to the end, as the server does, replacing an older copy of the same entry. */
    fun appended(
        queue: List<ListenQueueItem>,
        item: ListenQueueItem,
    ): List<ListenQueueItem> = queue.filterNot { it.isSameEntry(item) } + item

    /** Puts an entry first, as the web's Play Next does with position 0, replacing an older copy of it. */
    fun prepended(
        queue: List<ListenQueueItem>,
        item: ListenQueueItem,
    ): List<ListenQueueItem> = listOf(item) + queue.filterNot { it.isSameEntry(item) }

    /** Takes a story read aloud out of Up Next; a podcast queued from the same story stays. */
    fun without(
        queue: List<ListenQueueItem>,
        storyHash: String,
    ): List<ListenQueueItem> = queue.filterNot { it.isListen && it.storyHash == storyHash }

    fun withoutEntry(
        queue: List<ListenQueueItem>,
        entryId: String,
    ): List<ListenQueueItem> = queue.filterNot { it.entryId == entryId }

    /**
     * The entry that plays when the current one ends: the first one Android plays, when the web's auto-play setting
     * (auto_play_next) is on. Entries Android can't play, like videos, wait for the web.
     */
    fun next(
        queue: List<ListenQueueItem>,
        autoPlayNext: Boolean,
    ): ListenQueueItem? = if (autoPlayNext) playableItems(queue).firstOrNull() else null

    /**
     * The whole queue with its playable entries in a new order. Other entries keep their slots, so a video queued
     * on the web stays exactly where it was. Playable entries missing from the order keep their relative order after
     * the ones that were named.
     */
    fun withPlayableOrder(
        queue: List<ListenQueueItem>,
        orderedEntryIds: List<String>,
    ): List<ListenQueueItem> {
        val playable = playableItems(queue)
        val byId = playable.associateBy { it.entryId }
        val named = orderedEntryIds.distinct().mapNotNull { byId[it] }
        val ordered = named + playable.filterNot { it in named }
        val next = ordered.iterator()
        return queue.map { if (it.isPlayable) next.next() else it }
    }

    /** Moves the playable entry at from to to, both counted among the entries Up Next shows. */
    fun moved(
        queue: List<ListenQueueItem>,
        from: Int,
        to: Int,
    ): List<ListenQueueItem> {
        val ids = playableItems(queue).map { it.entryId }.toMutableList()
        if (from !in ids.indices || to !in ids.indices || from == to) return queue
        ids.add(to, ids.removeAt(from))
        return withPlayableOrder(queue, ids)
    }

    /** The queue_order the server's reorder expects: every entry, playable or not, as story_hash and media_url. */
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
            queue = parseItems(body.get(KEY_QUEUE)).map { it.first },
            history =
                parseItems(body.get(KEY_HISTORY)).map { (item, entry) ->
                    ListenHistoryEntry(
                        item = item,
                        positionSeconds = entry.double("position") ?: 0.0,
                        durationSeconds = entry.double("duration") ?: 0.0,
                    )
                },
            current = parseCurrent(body),
            settings = parseSettings(body),
            mediaSpeed = body.double("current_playback_rate")?.takeIf { it > 0.0 },
        )
    }

    private fun parseItems(element: JsonElement?): List<Pair<ListenQueueItem, JsonObject>> {
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
            ) to item
        }
    }

    /** The current_* fields MMediaPlaybackState.canonical() sends; an empty media URL means nothing is current. */
    private fun parseCurrent(body: JsonObject): ListenCurrentMedia? {
        val mediaUrl = body.string("current_media_url").orEmpty()
        if (mediaUrl.isEmpty()) return null
        return ListenCurrentMedia(
            storyHash = body.string("current_story_hash").orEmpty(),
            mediaUrl = mediaUrl,
            mediaType = body.string("current_media_type").orEmpty(),
            positionSeconds = body.double("current_position") ?: 0.0,
            durationSeconds = body.double("current_duration") ?: 0.0,
            title = body.string("current_media_title").orEmpty(),
            feedId = body.string("current_feed_id")?.takeIf { it.isNotEmpty() && it != "0" },
            imageUrl = body.string("current_image_url")?.takeIf { it.isNotEmpty() },
        )
    }

    /** The web's `state.skip_back_seconds || 15`: a missing or zero setting falls back to the default. */
    private fun parseSettings(body: JsonObject): ListenMediaSettings {
        val defaults = ListenMediaSettings()
        return ListenMediaSettings(
            skipBackSeconds = body.int("skip_back_seconds")?.takeIf { it > 0 } ?: defaults.skipBackSeconds,
            skipForwardSeconds = body.int("skip_forward_seconds")?.takeIf { it > 0 } ?: defaults.skipForwardSeconds,
            autoPlayNext = body.boolean("auto_play_next") ?: defaults.autoPlayNext,
            rememberPosition = body.boolean("remember_position") ?: defaults.rememberPosition,
        )
    }

    /** feed_id arrives as a number from the server but as a string from older clients. */
    private fun JsonObject.string(key: String): String? {
        val value = get(key)?.takeIf { it.isJsonPrimitive }?.asJsonPrimitive ?: return null
        return if (value.isNumber) value.asLong.toString() else value.asString
    }

    private fun JsonObject.double(key: String): Double? {
        val value = get(key)?.takeIf { it.isJsonPrimitive }?.asJsonPrimitive ?: return null
        return when {
            value.isNumber -> value.asDouble
            value.isString -> value.asString.toDoubleOrNull()
            else -> null
        }?.takeIf { it.isFinite() }
    }

    private fun JsonObject.int(key: String): Int? = double(key)?.toInt()

    private fun JsonObject.boolean(key: String): Boolean? {
        val value = get(key)?.takeIf { it.isJsonPrimitive }?.asJsonPrimitive ?: return null
        return when {
            value.isBoolean -> value.asBoolean
            value.isString -> value.asString.equals("true", ignoreCase = true)
            else -> null
        }
    }

    private const val KEY_PLAYBACK_STATE = "playback_state"
    private const val KEY_QUEUE = "queue"
    private const val KEY_HISTORY = "history"
}
