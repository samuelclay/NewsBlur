package com.newsblur.delegate

import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.view.Menu
import android.view.View
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import com.newsblur.activity.NbActivity
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.AnchoredPopover
import com.newsblur.util.PopupMenuTextScaler
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils
import io.mockk.*
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_ActionMenuHighlight {
    @Test
    fun test_feed_and_story_menu_hold_highlight_until_popup_detaches() {
        mockkConstructor(LinearLayout::class, ScrollView::class, GradientDrawable::class, ColorDrawable::class, LayerDrawable::class, PopupWindow::class)
        mockkStatic(UIUtils::class, View.MeasureSpec::class, AnchoredPopover::class)
        mockkObject(PopupMenuTextScaler)
        try {
            val prefs = mockk<PrefsRepo>(relaxed = true)
            val activity = mockk<NbActivity>(relaxed = true)
            every { activity.prefsRepo } returns prefs
            every { prefs.getListTextSize() } returns 1f
            every { UIUtils.dp2px(any(), any<Int>()) } answers { secondArg() }
            every { View.MeasureSpec.makeMeasureSpec(any(), any()) } returns 0
            every { PopupMenuTextScaler.scaledWidthPx(any(), any()) } answers { firstArg() }
            every { PopupMenuTextScaler.apply(any(), any()) } just Runs
            every { AnchoredPopover.show(any(), any(), any(), any(), any()) } just Runs
            every { anyConstructed<LinearLayout>().setOrientation(any()) } just Runs
            every { anyConstructed<LinearLayout>().setPadding(any(), any(), any(), any()) } just Runs
            every { anyConstructed<LinearLayout>().removeAllViews() } just Runs
            every { anyConstructed<ScrollView>().addView(any()) } just Runs
            every { anyConstructed<ScrollView>().setClipToOutline(any()) } just Runs
            every { anyConstructed<ScrollView>().setBackground(any()) } just Runs
            every { anyConstructed<ScrollView>().scrollTo(any(), any()) } just Runs
            every { anyConstructed<ScrollView>().measure(any(), any()) } just Runs
            every { anyConstructed<ScrollView>().measuredHeight } returns 100
            every { anyConstructed<GradientDrawable>().setCornerRadius(any()) } just Runs
            every { anyConstructed<GradientDrawable>().setColor(any<Int>()) } just Runs
            every { anyConstructed<GradientDrawable>().setStroke(any(), any<Int>()) } just Runs
            every { anyConstructed<PopupWindow>().isShowing } returns false
            every { anyConstructed<PopupWindow>().width } returns 304
            every { anyConstructed<PopupWindow>().setBackgroundDrawable(any()) } just Runs
            every { anyConstructed<PopupWindow>().setOutsideTouchable(any()) } just Runs
            every { anyConstructed<PopupWindow>().setElevation(any()) } just Runs
            every { anyConstructed<PopupWindow>().setInputMethodMode(any()) } just Runs
            every { anyConstructed<PopupWindow>().dismiss() } just Runs
            val menu = mockk<Menu> { every { size() } returns 0 }
            for (theme in listOf(ThemeValue.LIGHT, ThemeValue.DARK, ThemeValue.BLACK, ThemeValue.SEPIA)) {
                for (separateTitleAnchor in listOf(false, true)) {
                    val original = mockk<Drawable>(relaxed = true)
                    var foreground: Drawable? = original
                    val row = mockk<View>(relaxed = true)
                    every { row.foreground } answers { foreground }
                    every { row.setForeground(any()) } answers { foreground = firstArg() }
                    val cleanup = slot<View.OnAttachStateChangeListener>()
                    val rowDetach = slot<View.OnAttachStateChangeListener>()
                    every { row.addOnAttachStateChangeListener(capture(rowDetach)) } just Runs
                    every { anyConstructed<ScrollView>().addOnAttachStateChangeListener(capture(cleanup)) } just Runs
                    if (separateTitleAnchor) {
                        val title = mockk<View>(relaxed = true)
                        ActionMenuPopover.show(activity, title, row, menu, theme) { true }
                        verify(exactly = 0) { title.setForeground(any()) }
                    } else {
                        ActionMenuPopover.show(activity, row, menu, theme) { true }
                    }
                    assertNotSame("The selected row must remain visibly highlighted in $theme", original, foreground)
                    verify(exactly = 0) { row.setBackground(any()) }
                    // Test_ActionMenuHighlight.kt covers outside-tap/back/rotation teardown even when a caller owns OnDismissListener.
                    cleanup.captured.onViewDetachedFromWindow(mockk(relaxed = true))
                    assertSame("Dismissal must restore the row's existing foreground in $theme", original, foreground)

                    // Test_ActionMenuHighlight.kt keeps a recycled row's later styling safe from repeated teardown.
                    val replacement = mockk<Drawable>(relaxed = true)
                    foreground = replacement
                    rowDetach.captured.onViewDetachedFromWindow(row)
                    assertSame(replacement, foreground)
                }
            }
        } finally {
            unmockkAll()
        }
    }
}
