package com.newsblur.realtime

/**
 * One Socket.IO event from node/unread_counts.coffee, which emits (event, channel, message).
 * RealtimeMessage.kt mirrors the web's handle_realtime_update in media/js/newsblur/reader/reader.js.
 */
sealed interface RealtimeMessage {
    /** user:update story:read:<hash> or story:unread:<hash>. */
    data class StoryReadState(
        val storyHash: String,
        val read: Boolean,
    ) : RealtimeMessage

    /** user:update feed:<id>[,<id>], social:<id> or refresh:<id>,<id>. Ids are API ids, social ones prefixed. */
    data class CountsChanged(
        val feedIds: List<String>,
        val skipOpenList: Boolean,
    ) : RealtimeMessage

    /** user:update story:starred:<hash> or story:unstarred:<hash>. */
    data class StarredChanged(
        val storyHash: String?,
        val starred: Boolean,
    ) : RealtimeMessage

    data object InteractionNew : RealtimeMessage

    /** user:update reload:feeds or reload:<feed_id>: subscriptions or folders changed elsewhere. */
    data object ReloadFeeds : RealtimeMessage

    /** feed:update on a feed channel: utils/feed_fetcher.py fetched new stories for it. */
    data class FeedFetched(
        val feedId: String,
    ) : RealtimeMessage

    /** feed:story:new on <feed_id>:story, published per story by MStory.publish_to_subscribers. */
    data class NewStory(
        val feedId: String,
        val storyHash: String,
        val timestampSeconds: Long,
    ) : RealtimeMessage

    companion object {
        const val EVENT_USER_UPDATE = "user:update"
        const val EVENT_FEED_UPDATE = "feed:update"
        const val EVENT_STORY_NEW = "feed:story:new"
        val EVENTS = listOf(EVENT_USER_UPDATE, EVENT_FEED_UPDATE, EVENT_STORY_NEW)

        private const val SOCIAL_PREFIX = "social:"

        fun parse(
            event: String,
            arguments: List<Any?>,
        ): RealtimeMessage? {
            val channel = arguments.getOrNull(0)?.toString() ?: return null
            val message = arguments.getOrNull(1)?.toString() ?: return null
            return when (event) {
                EVENT_USER_UPDATE -> parseUserUpdate(message)
                EVENT_FEED_UPDATE -> parseFeedUpdate(channel)
                EVENT_STORY_NEW -> parseNewStory(channel, message)
                else -> null
            }
        }

        private fun parseUserUpdate(message: String): RealtimeMessage? =
            when {
                message.startsWith("story:read:") -> hashMessage(message, "story:read:") { StoryReadState(it, true) }
                message.startsWith("story:unread:") -> hashMessage(message, "story:unread:") { StoryReadState(it, false) }
                message.startsWith("story:starred") -> StarredChanged(trailingHash(message, "story:starred"), true)
                message.startsWith("story:unstarred") -> StarredChanged(trailingHash(message, "story:unstarred"), false)
                // apps/analyzer/views.py sends one comma-joined message for every feed a classifier touched.
                message.startsWith("feed:") -> ids(message.removePrefix("feed:"))?.let { CountsChanged(it, skipOpenList = true) }
                message.startsWith(SOCIAL_PREFIX) -> CountsChanged(listOf(message), skipOpenList = true)
                message.startsWith("refresh:") -> ids(message.removePrefix("refresh:"))?.let { CountsChanged(it, skipOpenList = false) }
                message == "interaction:new" -> InteractionNew
                message.startsWith("reload:") -> ReloadFeeds
                else -> null
            }

        private fun parseFeedUpdate(channel: String): RealtimeMessage? =
            when {
                channel.startsWith(SOCIAL_PREFIX) -> CountsChanged(listOf(channel), skipOpenList = false)
                channel.isNotBlank() && channel.all(Char::isDigit) -> FeedFetched(channel)
                else -> null
            }

        private fun parseNewStory(
            channel: String,
            message: String,
        ): RealtimeMessage? {
            val source = channel.removeSuffix(":story")
            // apps/social/models.py publishes every share on social:<user_id>:story, several a minute from
            // busy blurblogs. Like the web, blurblog counts follow reads (user:update social:<id>) instead.
            if (source.startsWith(SOCIAL_PREFIX)) return null
            val storyHash = message.substringBefore(',').trim()
            val timestamp = message.substringAfter(',', "").trim().toLongOrNull() ?: return null
            if (source.isBlank() || storyHash.isBlank()) return null
            return NewStory(source, storyHash, timestamp)
        }

        private inline fun hashMessage(
            message: String,
            prefix: String,
            build: (String) -> RealtimeMessage,
        ): RealtimeMessage? = message.removePrefix(prefix).takeIf { it.isNotBlank() }?.let(build)

        private fun trailingHash(
            message: String,
            prefix: String,
        ): String? = message.removePrefix(prefix).removePrefix(":").takeIf { it.isNotBlank() }

        private fun ids(list: String): List<String>? =
            list
                .split(',')
                .map(String::trim)
                .filter(String::isNotEmpty)
                .takeIf { it.isNotEmpty() }
    }
}
