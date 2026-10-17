package com.newsblur.activity

import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.coordinatorlayout.widget.CoordinatorLayout
import com.google.android.material.snackbar.Snackbar
import com.newsblur.R
import com.newsblur.databinding.ActivityReadingBinding
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.unmockkConstructor
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class Test_UnreadSnackbar {
    @Before
    fun setUp() {
        mockkStatic(Looper::class)
        every { Looper.getMainLooper() } returns mockk<Looper>()
        mockkConstructor(Handler::class)
        mockkStatic(Snackbar::class, UIUtils::class)
        mockkConstructor(GradientDrawable::class)
        every { UIUtils.dp2px(any(), any<Float>()) } answers { secondArg<Float>() }
        every { anyConstructed<GradientDrawable>().setShape(any()) } returns Unit
        every { anyConstructed<GradientDrawable>().setCornerRadius(any()) } returns Unit
        every { anyConstructed<GradientDrawable>().setColor(any<Int>()) } returns Unit
    }

    @After
    fun tearDown() {
        unmockkConstructor(GradientDrawable::class)
        unmockkStatic(Snackbar::class, UIUtils::class)
        unmockkConstructor(Handler::class)
        unmockkStatic(Looper::class)
    }

    @Test
    fun test_unread_count_uses_coordinator_params_and_preserves_anchor_and_theme() {
        for (theme in listOf(ThemeValue.LIGHT, ThemeValue.DARK, ThemeValue.BLACK, ThemeValue.SEPIA)) {
            val fixture = Fixture(theme)

            fixture.show()

            assertEquals(ViewGroup.LayoutParams.WRAP_CONTENT, fixture.params.width)
            assertEquals(Gravity.CENTER_HORIZONTAL or Gravity.BOTTOM, fixture.params.gravity)
            assertEquals(17, fixture.params.bottomMargin)
            verify { fixture.snackbar.anchorView = fixture.overlay }
            verify { fixture.snackView.layoutParams = fixture.params }
            verify { fixture.textView.setTextColor(fixture.palette.tintColor) }
            verify { anyConstructed<GradientDrawable>().setColor(fixture.palette.groupBackgroundColor) }
            verify(exactly = 1) { fixture.snackbar.show() }
        }
    }

    @Test
    fun test_tapping_again_updates_the_visible_unread_count() {
        val fixture = Fixture(ThemeValue.LIGHT)
        fixture.show()
        every { fixture.snackbar.isShown } returns true
        every { fixture.reading getProperty "unreadCount" } returns 1

        fixture.show()

        verify(exactly = 1) { fixture.snackbar.show() }
        verify { fixture.snackbar.setText("1 unread story") }
    }

    private class Fixture(theme: ThemeValue) {
        val reading = mockk<Reading>(relaxed = true)
        val snackbar = mockk<Snackbar>(relaxed = true)
        val snackView = mockk<View>(relaxed = true)
        val textView = mockk<TextView>(relaxed = true)
        val overlay = mockk<FrameLayout>(relaxed = true)
        val params = mockk<CoordinatorLayout.LayoutParams>(relaxed = true)
        private val binding = mockk<ActivityReadingBinding>(relaxed = true)
        private val traverseBar = ReadingTraverseBar(reading, binding, theme)
        val palette get() = traverseBar.palette

        init {
            params.bottomMargin = 17
            ActivityReadingBinding::class.java.getDeclaredField("contentBottomOverlay").apply {
                isAccessible = true
                set(binding, overlay)
            }
            every { Snackbar.make(binding.root, any<CharSequence>(), Snackbar.LENGTH_SHORT) } returns snackbar
            every { snackbar.view } returns snackView
            every { snackView.layoutParams } returns params
            every { snackView.findViewById<TextView>(com.google.android.material.R.id.snackbar_text) } returns textView
            every { reading getProperty "unreadCount" } returns 2
            every { reading.getString(R.string.overlay_count_toast_1) } returns "%d unread story"
            every { reading.getString(R.string.overlay_count_toast_N) } returns "%d unread stories"
            every { reading["showUnreadSnackbar"]() } answers { callOriginal() }
            setField("binding", binding)
            setField("traverseBar", traverseBar)
        }

        fun show() {
            Reading::class.java.getDeclaredMethod("showUnreadSnackbar").apply {
                isAccessible = true
                invoke(reading)
            }
        }

        private fun setField(name: String, value: Any) {
            Reading::class.java.getDeclaredField(name).apply {
                isAccessible = true
                set(reading, value)
            }
        }
    }
}
