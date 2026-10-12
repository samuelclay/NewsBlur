package com.newsblur.activity

import android.content.SharedPreferences
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.widget.FrameLayout
import androidx.appcompat.widget.AppCompatImageButton
import androidx.constraintlayout.widget.ConstraintLayout
import com.newsblur.databinding.ActivityReadingBinding
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.UIUtils
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_ReaderEndControls {
    @Test
    fun test_pinned_controls_stay_visible_with_a_hidden_toolbar() = withFixture { f ->
        f.firstFooter.top = 1100
        f.alwaysShowControls = true
        f.controller.start()
        f.reading.enableOverlays()
        assertEquals(1f, f.lastAlpha, 0f)
        f.applyAlpha(0.2f)
        assertEquals(1f, f.lastAlpha, 0f)
        assertTrue(f.reading.isToolbarHidden())

        f.alwaysShowControls = false
        f.reading.enableOverlays()
        assertEquals(0f, f.lastAlpha, 0f)
    }

    @Test
    fun test_fullscreen_video_overrides_pinned_controls_and_restores_them_on_exit() = withFixture { f ->
        f.firstFooter.top = 1100
        f.alwaysShowControls = true
        f.controller.start()
        f.reading.disableOverlays()
        assertEquals(0f, f.lastAlpha, 0f)
        f.firstFooter.top = 700
        f.frame.captured.onPreDraw()
        f.applyAlpha(1f)
        assertEquals(0f, f.lastAlpha, 0f)
        assertSame(f.host, f.parent)
        f.reading.enableOverlays()
        assertEquals(1f, f.lastAlpha, 0f)
    }

    @Test
    fun test_unset_preference_preserves_toolbar_fade_in_article_body() = withFixture { f ->
        f.firstFooter.top = 1100
        f.controller.start()
        f.applyAlpha(0.4f)
        assertEquals(0.4f, f.lastAlpha, 0f)
        f.applyAlpha(0f)
        assertEquals(0f, f.lastAlpha, 0f)
        assertSame(f.host, f.parent)
    }

    @Test
    fun test_pinned_controls_stay_floating_when_footer_scrolls_above_viewport() = withFixture { f ->
        f.alwaysShowControls = true
        f.controller.start()
        f.reading.enableOverlays()
        assertSame(f.host, f.parent)

        f.firstFooter.top = -100
        f.frame.captured.onPreDraw()
        f.applyAlpha(0f)
        assertFalse(f.controller.isDocked)
        assertSame(f.host, f.parent)
        assertEquals(1f, f.lastAlpha, 0f)
        verify(exactly = 0) { f.firstFooter.view.addView(any(), any<ViewGroup.LayoutParams>()) }
    }

    @Test
    fun test_preference_changes_return_docked_controls_to_host_and_restore_default_docking() = withFixture { f ->
        f.controller.start()
        assertSame(f.firstFooter.view, f.parent)

        f.alwaysShowControls = true
        f.controller.update()
        assertSame(f.host, f.parent)
        assertFalse(f.controller.isDocked)
        assertEquals(1f, f.lastAlpha, 0f)
        verify { f.firstFooter.view.removeOnAttachStateChangeListener(any()) }

        f.alwaysShowControls = false
        f.controller.update()
        assertSame(f.firstFooter.view, f.parent)
        assertTrue(f.controller.isDocked)
        assertEquals(1f, f.lastAlpha, 0f)

        f.firstFooter.top = 1100
        f.frame.captured.onPreDraw()
        assertSame(f.host, f.parent)
        assertEquals(0f, f.lastAlpha, 0f)
    }

    @Test
    fun test_article_end_restores_traversal_controls_without_revealing_top_toolbar() = withFixture { f ->
        f.controller.start()
        f.reading.enableOverlays()

        // Test_ReaderEndControls.kt keeps the original S22 regression: the top toolbar is hidden,
        // but the same Text/Share and Previous/Next views are now visible inside the article end.
        assertTrue(f.controller.isDocked)
        assertSame(f.firstFooter.view, f.parent)
        assertEquals(1f, f.lastAlpha, 0f)
        verify { f.firstFooter.view.addView(f.controls, f.params) }
        f.frame.captured.onPreDraw()
        verify(exactly = 1) { f.firstFooter.view.addView(f.controls, f.params) }
    }

    @Test
    fun test_scrolling_back_to_article_body_restores_floating_controls_and_auto_hide() = withFixture { f ->
        f.firstFooter.top = 1100
        f.controller.start()
        f.reading.enableOverlays()
        assertSame(f.host, f.parent)
        assertEquals(0f, f.lastAlpha, 0f)

        f.firstFooter.top = 700
        f.frame.captured.onPreDraw()
        assertSame(f.firstFooter.view, f.parent)
        assertEquals(1f, f.lastAlpha, 0f)

        f.firstFooter.top = 1100
        f.frame.captured.onPreDraw()
        assertSame(f.host, f.parent)
        assertFalse(f.controller.isDocked)
        assertEquals(0f, f.lastAlpha, 0f)
    }

    @Test
    fun test_partly_visible_footer_reveals_controls_and_keeps_them_when_scroll_position_shifts() = withFixture { f ->
        // Test_ReaderEndControls.kt: only the first 10px of the footer are above the 800px safe viewport bottom.
        f.firstFooter.top = 790
        f.controller.start()
        f.reading.enableOverlays()
        assertSame(f.firstFooter.view, f.parent)
        assertEquals(1f, f.lastAlpha, 0f)

        f.firstFooter.top = 700
        f.frame.captured.onPreDraw()
        f.firstFooter.top = 790
        f.frame.captured.onPreDraw()
        assertSame(f.firstFooter.view, f.parent)
        verify(exactly = 1) { f.firstFooter.view.addView(f.controls, f.params) }

        f.firstFooter.top = 800
        f.frame.captured.onPreDraw()
        assertSame(f.host, f.parent)
        assertEquals(0f, f.lastAlpha, 0f)
    }

    @Test
    fun test_page_changes_only_attach_controls_to_active_footer_and_detach_returns_them() = withFixture { f ->
        f.controller.start()
        val nextFooter = f.footer(top = 1100)
        f.activeFooter = nextFooter
        f.frame.captured.onPreDraw()
        assertSame(f.host, f.parent)

        nextFooter.top = 700
        f.frame.captured.onPreDraw()
        assertSame(nextFooter.view, f.parent)
        verify { f.firstFooter.view.removeOnAttachStateChangeListener(any()) }

        nextFooter.attached = false
        nextFooter.attachment.captured.onViewDetachedFromWindow(nextFooter.view)
        assertSame(f.host, f.parent)
        assertEquals(0f, f.lastAlpha, 0f)
        f.frame.captured.onPreDraw()
        assertSame(f.host, f.parent)
    }

    @Test
    fun test_fullscreen_suppresses_docked_controls_until_video_exits() = withFixture { f ->
        f.controller.start()
        f.reading.disableOverlays()
        assertEquals(0f, f.lastAlpha, 0f)
        f.firstFooter.top = 1100
        f.frame.captured.onPreDraw()
        f.firstFooter.top = 700
        f.frame.captured.onPreDraw()
        assertEquals(0f, f.lastAlpha, 0f)
        f.reading.enableOverlays()
        assertEquals(1f, f.lastAlpha, 0f)
    }

    @Test
    fun test_disposal_after_window_detach_removes_original_observer_and_releases_footer() = withFixture { f ->
        f.controller.start()
        f.hostAttachment.captured.onViewDetachedFromWindow(f.host)
        val detachedObserver = mockk<ViewTreeObserver>(relaxed = true)
        every { f.host.viewTreeObserver } returns detachedObserver
        f.controller.close()
        assertSame(f.host, f.parent)
        verify { f.observer.removeOnPreDrawListener(f.frame.captured) }
        verify { f.host.removeOnAttachStateChangeListener(f.hostAttachment.captured) }
        verify { f.firstFooter.view.removeOnAttachStateChangeListener(any()) }
        verify(exactly = 0) { detachedObserver.removeOnPreDrawListener(any()) }
    }

    private fun withFixture(block: (Fixture) -> Unit) {
        mockkStatic(UIUtils::class)
        try {
            block(Fixture())
        } finally {
            unmockkStatic(UIUtils::class)
        }
    }

    private class Footer(val view: FrameLayout, var top: Int) {
        var attached = true
        val attachment = slot<View.OnAttachStateChangeListener>()
    }

    private class Fixture {
        val reading = mockk<Reading>(relaxed = true)
        val binding = mockk<ActivityReadingBinding>(relaxed = true)
        val left = mockk<ConstraintLayout>(relaxed = true)
        val right = mockk<ConstraintLayout>(relaxed = true)
        val host = mockk<FrameLayout>(relaxed = true)
        val controls = mockk<ConstraintLayout>(relaxed = true)
        val params = mockk<ViewGroup.LayoutParams>()
        val observer = mockk<ViewTreeObserver>(relaxed = true)
        val frame = slot<ViewTreeObserver.OnPreDrawListener>()
        val hostAttachment = slot<View.OnAttachStateChangeListener>()
        var parent: ViewGroup? = host
        var lastAlpha = -1f
        var alwaysShowControls: Boolean? = null
        val firstFooter = footer(top = 700)
        var activeFooter: Footer? = firstFooter
        val controller: ReaderEndControls

        init {
            val preferences = mockk<SharedPreferences>(relaxed = true)
            every { preferences.getBoolean(any(), any()) } answers {
                if (firstArg<String>() == "reader_controls_always_visible") {
                    alwaysShowControls ?: secondArg<Boolean>()
                } else {
                    secondArg<Boolean>()
                }
            }
            every { reading.prefsRepo } returns PrefsRepo(preferences, mockk(relaxed = true))
            field(binding, ActivityReadingBinding::class.java, "readingOverlayLeftGroup", left)
            field(binding, ActivityReadingBinding::class.java, "readingOverlayRightGroup", right)
            field(binding, ActivityReadingBinding::class.java, "readingOverlaySend", mockk<AppCompatImageButton>(relaxed = true))
            field(binding, ActivityReadingBinding::class.java, "readingOverlayLeftSeparator", mockk<View>(relaxed = true))
            field(reading, Reading::class.java, "binding", binding)
            field(reading, Reading::class.java, "toolbarVisibleFraction", 0f)
            every { binding.root.measuredWidth } returns 0
            every { reading.runOnUiThread(any()) } answers { firstArg<Runnable>().run() }
            every { reading.enableOverlays() } answers { callOriginal() }
            every { reading.disableOverlays() } answers { callOriginal() }
            every { reading.isToolbarHidden() } answers { callOriginal() }
            every { reading["setOverlayAlpha"](any<Float>()) } answers { callOriginal() }
            every { UIUtils.setViewAlpha(any(), any(), any()) } just Runs
            every { UIUtils.setViewAlpha(left, any(), true) } answers { lastAlpha = secondArg() }
            every { controls.parent } answers { parent }
            every { controls.layoutParams } returns params
            every { host.isAttachedToWindow } returns true
            every { host.isLaidOut } returns true
            every { host.paddingBottom } returns 24
            val hostParams = mockk<ViewGroup.MarginLayoutParams>(relaxed = true)
            hostParams.bottomMargin = 12
            every { host.layoutParams } returns hostParams
            // Test_ReaderEndControls.kt models the floating host shrinking after its only control row moves out.
            every { host.height } answers { if (parent === host) 68 else 24 }
            every { host.getLocationOnScreen(any()) } answers { firstArg<IntArray>()[1] = 812 - host.height }
            every { host.viewTreeObserver } returns observer
            every { observer.isAlive } returns true
            every { observer.addOnPreDrawListener(capture(frame)) } just Runs
            every { host.addOnAttachStateChangeListener(capture(hostAttachment)) } just Runs
            every { host.removeView(controls) } answers { parent = null }
            every { host.addView(controls, params) } answers { parent = host }
            controller = ReaderEndControls(
                host,
                controls,
                { activeFooter?.view },
                { applyAlpha(0f) },
                shouldDock = { !reading.prefsRepo.isReaderControlsAlwaysVisible() },
            )
            field(reading, Reading::class.java, "endControls", controller)
        }

        fun footer(top: Int): Footer {
            val footer = Footer(mockk(relaxed = true), top)
            every { footer.view.isAttachedToWindow } answers { footer.attached }
            every { footer.view.isShown } returns true
            every { footer.view.isLaidOut } returns true
            every { footer.view.height } returns 44
            every { footer.view.getLocationOnScreen(any()) } answers { firstArg<IntArray>()[1] = footer.top }
            every { footer.view.addOnAttachStateChangeListener(capture(footer.attachment)) } just Runs
            every { footer.view.removeView(controls) } answers { parent = null }
            every { footer.view.addView(controls, params) } answers { parent = footer.view }
            return footer
        }

        fun applyAlpha(alpha: Float) {
            Reading::class.java.getDeclaredMethod("setOverlayAlpha", Float::class.javaPrimitiveType).apply {
                isAccessible = true
                invoke(reading, alpha)
            }
        }

        private fun field(owner: Any, type: Class<*>, name: String, value: Any) {
            type.getDeclaredField(name).apply {
                isAccessible = true
                set(owner, value)
            }
        }
    }
}
