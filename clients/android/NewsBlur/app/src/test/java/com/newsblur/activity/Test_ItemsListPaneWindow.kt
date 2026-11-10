package com.newsblur.activity

import android.content.res.Configuration
import android.view.View
import android.widget.ImageButton
import androidx.appcompat.widget.TooltipCompat
import androidx.core.util.Consumer
import com.newsblur.R
import com.newsblur.databinding.ActivityItemslistBinding
import com.newsblur.util.EdgeToEdgeUtil
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.StorySplitView
import com.newsblur.util.UIUtils
import io.mockk.every
import io.mockk.Runs
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkStatic
import io.mockk.verify
import io.mockk.verifyOrder
import org.junit.After
import org.junit.Before
import org.junit.Test

class Test_ItemsListPaneWindow {
    @Before
    fun setUp() {
        mockkStatic(EdgeToEdgeUtil::class, StorySplitView::class, UIUtils::class, TooltipCompat::class)
    }

    @After
    fun tearDown() {
        unmockkStatic(EdgeToEdgeUtil::class, StorySplitView::class, UIUtils::class, TooltipCompat::class)
    }

    @Test
    fun test_split_overlay_attaches_after_content_replacement() {
        val titles = mockk<ItemsList>(relaxed = true)
        val binding = mockk<ActivityItemslistBinding>(relaxed = true)
        ItemsList::class.java.getDeclaredField("binding").apply {
            isAccessible = true
            set(titles, binding)
        }
        every { titles.applyView(binding) } returns Unit
        every { StorySplitView.trackSplit(titles, any()) } returns Unit
        every { titles["installStoryListLayout"]() } answers { callOriginal() }

        invoke(titles, "installStoryListLayout")

        // EdgeToEdgeUtil.kt replaces the content view and would remove an already attached divider.
        verifyOrder {
            titles.applyView(binding)
            StorySplitView.trackSplit(titles, any())
        }
    }

    @Test
    fun test_configuration_after_split_callback_restores_the_fullscreen_exit_button() {
        val titles = mockk<ItemsList>(relaxed = true)
        val binding = mockk<ActivityItemslistBinding>(relaxed = true)
        val button = mockk<ImageButton>(relaxed = true)
        val splitCallback = slot<() -> Unit>()
        val configurationCallback = slot<Consumer<Configuration>>()
        ItemsList::class.java.getDeclaredField("binding").apply {
            isAccessible = true
            set(titles, binding)
        }
        every { titles.applyView(binding) } returns Unit
        every { StorySplitView.trackSplit(titles, capture(splitCallback)) } returns Unit
        every { titles.addOnConfigurationChangedListener(capture(configurationCallback)) } just Runs
        every { titles["installStoryListLayout"]() } answers { callOriginal() }
        every { titles["updateStoryListFullscreenButton"]() } answers { callOriginal() }
        every { titles.findViewById<ImageButton>(R.id.toolbar_fullscreen_button) } returns button
        every { StorySplitView.isStoryListFullscreen(titles) } returns true
        every { StorySplitView.canToggleStoryListFullscreen(titles) } returnsMany listOf(false, true)
        every { TooltipCompat.setTooltipText(any(), any()) } returns Unit

        invoke(titles, "installStoryListLayout")
        // ItemsList.java can hear the split collapse before Android delivers its wider configuration.
        splitCallback.captured.invoke()
        configurationCallback.captured.accept(mockk(relaxed = true))

        verifyOrder {
            button.visibility = View.GONE
            button.visibility = View.VISIBLE
        }
        verify { button.setImageResource(R.drawable.ic_reader_fullscreen_exit) }
    }

    @Test
    fun test_tablet_window_stays_opaque_after_a_resize_collapses_its_split() {
        val titles = windowFixture()
        val window = titles.window
        every { StorySplitView.isInSplit(titles) } returnsMany listOf(true, false)

        invoke(titles, "updateStoryListWindowBackground")
        invoke(titles, "updateStoryListWindowBackground")

        verify(exactly = 1) { window.setBackgroundDrawableResource(R.color.item_background) }
        verify(exactly = 0) { window.setBackgroundDrawableResource(android.R.color.transparent) }
    }

    @Test
    fun test_tablet_root_is_opaque_before_split_callbacks_arrive() {
        val titles = windowFixture()
        every { StorySplitView.slidesOverFeedDrawer(titles) } returns true

        invoke(titles, "updateStoryListWindowBackground")

        verify { titles.window.setBackgroundDrawableResource(R.color.item_background) }
    }

    @Test
    fun test_phone_preserves_the_transparent_swipe_back_window() {
        val titles = windowFixture()

        invoke(titles, "updateStoryListWindowBackground")

        verify { titles.window.setBackgroundDrawableResource(android.R.color.transparent) }
    }

    private fun windowFixture(): ItemsList {
        val titles = mockk<ItemsList>(relaxed = true)
        every { StorySplitView.isInSplit(titles) } returns false
        every { StorySplitView.slidesOverFeedDrawer(titles) } returns false
        every { UIUtils.getThemedResource(titles, R.attr.layoutBackground, android.R.attr.background) } returns R.color.item_background
        every { titles["updateStoryListWindowBackground"]() } answers { callOriginal() }
        return titles
    }

    private fun invoke(titles: ItemsList, method: String) {
        ItemsList::class.java.getDeclaredMethod(method).apply {
            isAccessible = true
            invoke(titles)
        }
    }
}
