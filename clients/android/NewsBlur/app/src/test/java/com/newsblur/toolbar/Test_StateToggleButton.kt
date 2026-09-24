package com.newsblur.toolbar

import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.newsblur.databinding.StateToggleBinding
import com.newsblur.util.StateFilter
import com.newsblur.view.StateToggleButton
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import org.junit.Assert.assertEquals
import org.junit.Test

@Suppress("ktlint:standard:class-naming")
class Test_StateToggleButton {
    @Test
    fun test_icon_only_filters_center_content_inside_pressed_highlight() {
        val document = java.nio.file.Files.newInputStream(java.nio.file.Paths.get("src/main/res/layout/state_toggle.xml")).use {
            javax.xml.parsers.DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(it)
        }
        val layouts = document.getElementsByTagName("LinearLayout")
        for (index in 0 until layouts.length) {
            val attributes = layouts.item(index).attributes
            val id = attributes.getNamedItem("android:id")?.nodeValue
            if (id !in listOf("@+id/toggle_all", "@+id/toggle_some", "@+id/toggle_focus", "@+id/toggle_saved")) continue
            val gravity = attributes.getNamedItem("android:gravity").nodeValue.split('|')
            org.junit.Assert.assertTrue("$id must center its icon horizontally within the minimum touch width", "center" in gravity || "center_horizontal" in gravity)
        }
    }

    @Test
    fun test_narrow_toolbar_keeps_selected_filter_label() {
        withToolbar { toolbar ->
            toolbar.measure(250, StateFilter.SOME)
            toolbar.assertLabels(View.VISIBLE, View.GONE, View.GONE)
        }
    }

    @Test
    fun test_narrow_toolbar_updates_label_when_selection_changes() {
        withToolbar { toolbar ->
            toolbar.measure(250, StateFilter.SOME)
            toolbar.measure(250, StateFilter.BEST)
            toolbar.assertLabels(View.GONE, View.VISIBLE, View.GONE)
            toolbar.measure(250, StateFilter.SAVED)
            toolbar.assertLabels(View.GONE, View.GONE, View.VISIBLE)
            toolbar.measure(250, StateFilter.ALL)
            toolbar.assertLabels(View.GONE, View.GONE, View.GONE)
        }
    }

    @Test
    fun test_widening_toolbar_restores_all_labels_and_narrowing_keeps_selection() {
        withToolbar { toolbar ->
            toolbar.measure(250, StateFilter.SAVED)
            toolbar.measure(500, StateFilter.SAVED)
            toolbar.assertLabels(View.VISIBLE, View.VISIBLE, View.VISIBLE)
            toolbar.measure(250, StateFilter.SAVED)
            toolbar.assertLabels(View.GONE, View.GONE, View.VISIBLE)
        }
    }

    @Test
    fun test_labels_stay_visible_when_natural_width_fits_exactly() {
        withToolbar { toolbar ->
            toolbar.measure(400, StateFilter.ALL)
            toolbar.assertLabels(View.VISIBLE, View.VISIBLE, View.VISIBLE)
        }
    }

    private fun withToolbar(test: (Toolbar) -> Unit) {
        mockkStatic(View.MeasureSpec::class)
        try {
            test(Toolbar())
        } finally {
            unmockkStatic(View.MeasureSpec::class)
        }
    }

    private class Toolbar {
        private val binding = mockk<StateToggleBinding>(relaxed = true)
        private val labels = List(3) { label(View.GONE) }
        private val allLabel = label(View.VISIBLE)
        private val view = mockk<StateToggleButton>(relaxed = true)

        init {
            for ((field, value) in mapOf(
                "toggleAllText" to allLabel,
                "toggleSomeText" to labels[0],
                "toggleFocusText" to labels[1],
                "toggleSavedText" to labels[2],
            )) {
                StateToggleBinding::class.java.getDeclaredField(field).apply { isAccessible = true }.set(binding, value)
            }
            for (field in listOf("toggleAll", "toggleSome", "toggleFocus", "toggleSaved")) {
                StateToggleBinding::class.java.getDeclaredField(field).apply { isAccessible = true }
                    .set(binding, mockk<LinearLayout>(relaxed = true))
            }
            for (button in listOf(binding.toggleAll, binding.toggleSome, binding.toggleFocus, binding.toggleSaved)) {
                every { button.childCount } returns 0
                every { button.minimumWidth } returns 100
                every { button.layoutParams } returns LinearLayout.LayoutParams(0, 0)
            }
            StateToggleButton::class.java.getDeclaredField("binding").apply { isAccessible = true }.set(view, binding)
            // Test_StateToggleButton.kt invokes actual measurement with mocked views without changing a device session.
            every { view["onMeasure"](any<Int>(), any<Int>()) } answers { callOriginal() }
        }

        fun measure(width: Int, state: StateFilter) {
            StateToggleButton::class.java.getDeclaredField("state").apply { isAccessible = true }.set(view, state)
            every { View.MeasureSpec.getSize(any()) } returns width
            every { View.MeasureSpec.getMode(any()) } returns View.MeasureSpec.AT_MOST
            try {
                StateToggleButton::class.java.getDeclaredMethod("onMeasure", Int::class.javaPrimitiveType, Int::class.javaPrimitiveType)
                    .apply { isAccessible = true }.invoke(view, width, 48)
            } catch (exception: java.lang.reflect.InvocationTargetException) {
                // StateToggleButton.kt applies visibility before delegating measurement to the Android framework.
                if (exception.cause?.message?.startsWith("Method onMeasure in android.widget.LinearLayout not mocked") != true) throw exception
            }
        }

        fun assertLabels(unread: Int, focus: Int, saved: Int) {
            assertEquals("All must always retain its label", View.VISIBLE, allLabel.visibility)
            assertEquals("Unread label", unread, labels[0].visibility)
            assertEquals("Focus label", focus, labels[1].visibility)
            assertEquals("Saved label", saved, labels[2].visibility)
        }

        private fun label(initialVisibility: Int): TextView {
            var visibility = initialVisibility
            return mockk<TextView>(relaxed = true) {
                every { getVisibility() } answers { visibility }
                every { setVisibility(any()) } answers { visibility = firstArg() }
            }
        }
    }
}
