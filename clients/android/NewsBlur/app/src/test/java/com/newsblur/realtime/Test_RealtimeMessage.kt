package com.newsblur.realtime

import com.newsblur.realtime.RealtimeMessage.CountsChanged
import com.newsblur.realtime.RealtimeMessage.FeedFetched
import com.newsblur.realtime.RealtimeMessage.NewStory
import com.newsblur.realtime.RealtimeMessage.StarredChanged
import com.newsblur.realtime.RealtimeMessage.StoryReadState
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_RealtimeMessage {
    private fun parse(
        event: String,
        channel: Any,
        message: String,
    ) = RealtimeMessage.parse(event, listOf(channel, message))

    @Test
    fun test_user_updates_keep_full_story_hashes_and_feed_lists() {
        // Story hashes carry their own colon (feed:guid), so only the prefix may be stripped.
        assertEquals(StoryReadState("6:2a3b4c", true), parse("user:update", "sam", "story:read:6:2a3b4c"))
        assertEquals(StoryReadState("6:2a3b4c", false), parse("user:update", "sam", "story:unread:6:2a3b4c"))
        assertEquals(StarredChanged("6:2a3b4c", true), parse("user:update", "sam", "story:starred:6:2a3b4c"))
        assertEquals(StarredChanged("6:2a3b4c", false), parse("user:update", "sam", "story:unstarred:6:2a3b4c"))
        // apps/analyzer/views.py joins every feed a classifier touched into one message.
        assertEquals(CountsChanged(listOf("12", "34"), skipOpenList = true), parse("user:update", "sam", "feed:12,34"))
        assertEquals(CountsChanged(listOf("social:99"), skipOpenList = true), parse("user:update", "sam", "social:99"))
        assertEquals(CountsChanged(listOf("12", "34"), skipOpenList = false), parse("user:update", "sam", "refresh:12,34"))
        assertEquals(RealtimeMessage.ReloadFeeds, parse("user:update", "sam", "reload:feeds"))
        assertEquals(RealtimeMessage.ReloadFeeds, parse("user:update", "sam", "reload:42"))
        assertEquals(RealtimeMessage.InteractionNew, parse("user:update", "sam", "interaction:new"))
    }

    @Test
    fun test_feed_channels_become_fetches_counts_or_new_stories() {
        assertEquals(FeedFetched("42"), parse("feed:update", "42", "story:new_count:3"))
        assertEquals(CountsChanged(listOf("social:7"), skipOpenList = false), parse("feed:update", "social:7", "story:new"))
        assertEquals(NewStory("42", "42:abc", 1_700_000_000L), parse("feed:story:new", "42:story", "42:abc,1700000000"))
        // Shares on social:<user_id>:story arrive several a minute from busy blurblogs; the web ignores them too.
        assertEquals(null, parse("feed:story:new", "social:7:story", "42:abc,1700000000"))
    }

    @Test
    fun test_messages_mobile_does_not_act_on_are_ignored() {
        assertEquals(null, parse("user:update", "sam", "notification:42:abc,Title"))
        assertEquals(null, parse("user:update", "sam", "search_index_complete:done"))
        assertEquals(null, parse("user:update", "sam", "fetch_archive:start"))
        assertEquals(null, parse("feed:story:new", "42:story", "42:abc"))
        assertEquals(null, RealtimeMessage.parse("ask_ai:chunk", listOf(mapOf("chunk" to "hi"))))
    }
}
