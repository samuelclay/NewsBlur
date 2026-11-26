package com.newsblur.activity

import com.google.android.material.button.MaterialButtonToggleGroup
import com.newsblur.databinding.ViewNotificationsItemBinding
import com.newsblur.domain.Feed
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkClass
import io.mockk.runs
import io.mockk.slot
import io.mockk.spyk
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_NotificationsAdapter {
    @Test
    fun test_replayed_and_replaced_feeds_keep_recycler_count_in_sync() {
        val adapter = spyk(NotificationsAdapter(mockk(), mockk()))
        var recyclerCount = 0
        every { adapter.notifyItemRangeInserted(any(), any()) } answers { recyclerCount += secondArg<Int>() }
        every { adapter.notifyItemRangeRemoved(any(), any()) } answers { recyclerCount -= secondArg<Int>() }
        every { adapter.notifyDataSetChanged() } answers { recyclerCount = adapter.itemCount }

        val feeds = listOf(Feed().apply { feedId = "1" }, Feed().apply { feedId = "2" })
        // NotificationsActivity.kt collects the same StateFlow again each time it returns to STARTED.
        for (snapshot in listOf(feeds, feeds, feeds.takeLast(1), emptyList())) {
            adapter.refreshFeeds(snapshot)
            assertEquals(snapshot.size, adapter.itemCount)
            assertEquals(adapter.itemCount, recyclerCount)
        }
    }

    @Test
    fun test_each_platform_button_toggles_its_own_channel() {
        val binding = notificationRow()
        every { binding.btnEmail.id } returns 1
        every { binding.btnWeb.id } returns 2
        every { binding.btnIos.id } returns 3
        every { binding.btnAndroid.id } returns 4
        val platformTaps = slot<MaterialButtonToggleGroup.OnButtonCheckedListener>()
        every { binding.groupPlatform.addOnButtonCheckedListener(capture(platformTaps)) } just runs
        val listener = mockk<NotificationsAdapter.Listener>(relaxed = true)
        val feed = Feed().apply { feedId = "1" }

        NotificationsAdapter.ViewHolder(binding, mockk(relaxed = true)).bind(feed, listener)

        platformTaps.captured.onButtonChecked(binding.groupPlatform, 4, true)
        assertEquals(listOf("android"), feed.notificationTypes)
        platformTaps.captured.onButtonChecked(binding.groupPlatform, 3, true)
        assertEquals(listOf("android", "ios"), feed.notificationTypes)
        platformTaps.captured.onButtonChecked(binding.groupPlatform, 4, false)
        assertEquals(listOf("ios"), feed.notificationTypes)
        verify(exactly = 3) { listener.onFeedUpdated(feed) }
        // NotificationsActivity.kt turns the device's notifications on for the Android tap only.
        verify(exactly = 1) { listener.onAndroidNotificationsEnabled() }
    }

    @Test
    fun test_changing_the_filter_keeps_the_feeds_channels() {
        val binding = notificationRow()
        every { binding.btnUnread.id } returns 1
        every { binding.btnFocus.id } returns 2
        val filterTaps = slot<MaterialButtonToggleGroup.OnButtonCheckedListener>()
        every { binding.groupFilter.addOnButtonCheckedListener(capture(filterTaps)) } just runs
        val feed =
            Feed().apply {
                feedId = "1"
                notificationFilter = Feed.NOTIFY_FILTER_UNREAD
                notificationTypes = mutableListOf("ios")
            }

        NotificationsAdapter.ViewHolder(binding, mockk(relaxed = true)).bind(feed, mockk(relaxed = true))
        filterTaps.captured.onButtonChecked(binding.groupFilter, 2, true)

        assertEquals(Feed.NOTIFY_FILTER_FOCUS, feed.notificationFilter)
        assertEquals(listOf("ios"), feed.notificationTypes)
    }

    @Test
    fun test_rebinding_a_recycled_row_does_not_replay_the_previous_feeds_taps() {
        val binding = notificationRow()
        every { binding.btnIos.id } returns 3
        every { binding.btnAndroid.id } returns 4
        val attached = mutableListOf<MaterialButtonToggleGroup.OnButtonCheckedListener>()
        every { binding.groupPlatform.addOnButtonCheckedListener(capture(attached)) } just runs
        every { binding.groupPlatform.clearOnButtonCheckedListeners() } answers { attached.clear() }
        // The real group reports every check() to its listeners, including the ones bind() makes to show a feed.
        every { binding.groupPlatform.check(any()) } answers {
            attached.toList().forEach { it.onButtonChecked(binding.groupPlatform, firstArg(), true) }
        }
        val listener = mockk<NotificationsAdapter.Listener>(relaxed = true)
        val holder = NotificationsAdapter.ViewHolder(binding, mockk(relaxed = true))
        val scrolledAway = Feed().apply { feedId = "1"; notificationTypes = mutableListOf("ios") }
        val scrolledTo = Feed().apply { feedId = "2"; notificationTypes = mutableListOf("ios", "android") }

        holder.bind(scrolledAway, listener)
        holder.bind(scrolledTo, listener)

        // Nobody tapped anything: the first feed keeps its channels and the device's notifications stay as they were.
        assertEquals(listOf("ios"), scrolledAway.notificationTypes)
        verify(exactly = 0) { listener.onFeedUpdated(any()) }
        verify(exactly = 0) { listener.onAndroidNotificationsEnabled() }
        verify(exactly = 2) { binding.groupPlatform.clearChecked() }
    }

    /** ViewNotificationsItemBinding only has a private constructor, normally reached by inflating the layout. */
    private fun notificationRow(): ViewNotificationsItemBinding {
        val constructor = ViewNotificationsItemBinding::class.java.declaredConstructors.single()
        constructor.isAccessible = true
        val views = constructor.parameterTypes.map { mockkClass(it.kotlin, relaxed = true) }
        return constructor.newInstance(*views.toTypedArray()) as ViewNotificationsItemBinding
    }
}
