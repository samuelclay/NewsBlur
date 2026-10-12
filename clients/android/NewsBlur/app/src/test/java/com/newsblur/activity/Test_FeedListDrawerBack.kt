package com.newsblur.activity

import androidx.activity.OnBackPressedCallback
import androidx.activity.OnBackPressedDispatcher
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.junit.Test

class Test_FeedListDrawerBack {
    @Test
    fun test_back_from_feeds_leaves_the_task_instead_of_reopening_titles() {
        val drawer = mockk<FeedListDrawer>(relaxed = true)
        val dispatcher = mockk<OnBackPressedDispatcher>(relaxed = true)
        val callback = slot<OnBackPressedCallback>()
        every { drawer.onBackPressedDispatcher } returns dispatcher
        every { dispatcher.addCallback(drawer, capture(callback)) } just Runs
        every { drawer["registerBackNavigation"]() } answers { callOriginal() }
        every { drawer["backFromFeeds"]() } answers { callOriginal() }
        // FeedListDrawer.kt must distinguish system Back from dismissing its scrim.
        FeedListDrawer::class.java.getDeclaredMethod("registerBackNavigation").apply {
            isAccessible = true
            invoke(drawer)
        }
        callback.captured.handleOnBackPressed()
        verify(exactly = 1) { drawer.moveTaskToBack(true) }
        verify(exactly = 0) { drawer.close() }
    }
}
