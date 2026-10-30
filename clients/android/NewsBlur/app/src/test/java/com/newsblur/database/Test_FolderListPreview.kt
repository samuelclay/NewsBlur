package com.newsblur.database

import com.newsblur.domain.Feed
import com.newsblur.util.FeedListOrder
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.StateFilter
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_FolderListPreview {
    @Test
    fun test_preview_before_folders_load_is_visible_without_crashing() {
        val adapter = fixture()
        val preview = previewFeed()

        adapter.setTryFeed(preview)
        adapter.forceRecount()

        assertEquals(listOf(preview), children(adapter).flatten())
        assertEquals(1, adapter.lastFeedCount)
        adapter.setTryFeed(null)
        assertEquals(emptyList<Feed>(), children(adapter).flatten())
    }

    @Test
    fun test_search_can_hide_and_restore_preview_without_folders() {
        val adapter = fixture()
        val preview = previewFeed()
        adapter.activeSearchQuery = "unrelated"
        adapter.setTryFeed(preview)
        assertEquals(emptyList<Feed>(), children(adapter).flatten())

        adapter.activeSearchQuery = "preview"
        adapter.forceRecount()
        assertEquals(listOf(preview), children(adapter).flatten())
    }

    private fun fixture(): FolderListAdapter {
        val prefs = mockk<PrefsRepo>(relaxed = true)
        every { prefs.getFeedListOrder() } returns FeedListOrder.ALPHABETICAL
        // FolderListAdapter.java's real recount path needs no Android views or database calls.
        val adapter = mockk<FolderListAdapter>(relaxed = true)
        every { adapter.setTryFeed(any()) } answers { callOriginal() }
        every { adapter.forceRecount() } answers { callOriginal() }
        every { adapter["recountFeeds"]() } answers { callOriginal() }
        every { adapter["recountSocialFeeds"]() } answers { callOriginal() }
        every { adapter["recountChildren"]() } answers { callOriginal() }
        every { adapter["getRootFolderIndex"]() } answers { callOriginal() }
        every { adapter["addSpecialRow"](any<String>()) } answers { callOriginal() }
        for (name in listOf("feeds", "feedNeutCounts", "feedPosCounts", "feedSavedCounts", "folders", "flatFolders")) {
            setField(adapter, name, linkedMapOf<String, Any>())
        }
        for (name in listOf("socialFeedsOrdered", "socialFeedsActive", "starredCountsByTag")) {
            setField(adapter, name, arrayListOf<Any>())
        }
        setField(adapter, "closedFolders", hashSetOf<String>())
        setField(adapter, "currentState", StateFilter.SOME)
        setField(adapter, "prefsRepo", prefs)
        return adapter
    }

    private fun setField(adapter: FolderListAdapter, name: String, value: Any) {
        FolderListAdapter::class.java.getDeclaredField(name).apply { isAccessible = true }.set(adapter, value)
    }

    private fun previewFeed() = Feed().apply {
        feedId = "123"
        title = "Preview feed"
    }

    @Suppress("UNCHECKED_CAST")
    private fun children(adapter: FolderListAdapter): List<List<Feed>> =
        FolderListAdapter::class.java.getDeclaredField("activeFolderChildren")
            .apply { isAccessible = true }.get(adapter) as List<List<Feed>>
}
