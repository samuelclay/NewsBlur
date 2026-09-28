package com.newsblur.activity

import android.view.View
import android.view.ViewPropertyAnimator
import android.widget.ImageView
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.lang.reflect.InvocationTargetException
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_StoryListSwipeFinish {
    @Test
    fun test_finishing_pause_does_not_restore_departing_story_surface() {
        val titles = pausedTitles(finishing = true)

        invokeLifecycle(titles, "onPause")

        verify(exactly = 0) { titles["resetInteractiveStoryListSwipe"](any<Boolean>()) }
    }

    @Test
    fun test_ordinary_pause_cancels_and_resets_an_interrupted_swipe() {
        val titles = pausedTitles(finishing = false)

        invokeLifecycle(titles, "onPause")

        verify(exactly = 1) { titles["resetInteractiveStoryListSwipe"](true) }
    }

    @Test
    fun test_destroy_releases_animation_and_snapshot_without_resetting_surface() {
        val titles = mockk<ItemsList>(relaxed = true)
        val surface = mockk<View>(relaxed = true)
        val animation = mockk<ViewPropertyAnimator>(relaxed = true)
        val underlay = mockk<ImageView>(relaxed = true)
        every { surface.animate() } returns animation
        every { titles.isChangingConfigurations } returns true
        every { titles["onDestroy"]() } answers { callOriginal() }
        every { titles["hideInteractiveSwipeUnderlay"]() } answers { callOriginal() }
        setField(titles, "interactiveSwipeSurface", surface)
        setField(titles, "interactiveSwipeUnderlay", underlay)

        invokeLifecycle(titles, "onDestroy")

        verify(exactly = 1) { animation.cancel() }
        verify(exactly = 1) { underlay.setImageDrawable(null) }
        verify(exactly = 0) { surface.translationX = any() }
        verify(exactly = 0) { titles["resetInteractiveStoryListSwipe"](any<Boolean>()) }
    }

    private fun pausedTitles(finishing: Boolean): ItemsList {
        val titles = mockk<ItemsList>(relaxed = true)
        every { titles.isFinishing } returns finishing
        every { titles["onPause"]() } answers { callOriginal() }
        every { titles["setStorySearchRefreshInFlight"](any<Boolean>()) } returns Unit
        every { titles["cancelPendingStorySearch"]() } returns Unit
        every { titles["cancelPendingFetchingBanner"]() } returns Unit
        every { titles["cancelStoryStatusBannerAnimation"]() } returns Unit
        every { titles["dismissItemListMenuPopup"]() } returns Unit
        every { titles["resetInteractiveStoryListSwipe"](any<Boolean>()) } returns Unit
        return titles
    }

    private fun invokeLifecycle(titles: ItemsList, method: String) {
        try {
            ItemsList::class.java.getDeclaredMethod(method).apply { isAccessible = true }.invoke(titles)
        } catch (error: InvocationTargetException) {
            // Test_StoryListSwipeFinish.kt stops at Android's framework boundary, after the app's lifecycle cleanup.
            val message = error.cause?.message.orEmpty()
            if (!message.contains("not mocked")) throw error
        }
    }

    private fun setField(titles: ItemsList, name: String, value: Any) {
        ItemsList::class.java.getDeclaredField(name).apply { isAccessible = true }.set(titles, value)
    }
}
