package com.newsblur.util

import android.app.Activity
import android.content.res.Resources
import android.util.TypedValue
import android.view.View
import android.view.Window
import android.widget.LinearLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.viewbinding.ViewBinding
import com.newsblur.R
import com.newsblur.util.EdgeToEdgeUtil.applyView
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkConstructor
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import io.mockk.verify
import org.junit.After
import org.junit.Test

class ReaderSystemBarThemeTest {
    @After fun cleanup() = unmockkAll()

    @Test fun recreatedReaderExplicitlyDrawsBehindSystemBarsBeforeHandlingInsets() {
        mockkConstructor(TypedValue::class)
        mockkStatic(WindowCompat::class)
        mockkStatic(ViewCompat::class)
        every { WindowCompat.setDecorFitsSystemWindows(any(), any()) } returns Unit
        every { ViewCompat.setOnApplyWindowInsetsListener(any(), any()) } returns Unit
        val activity = themedActivity()
        val window = mockk<Window>(relaxed = true)
        every { activity.window } returns window
        every { activity.findViewById<View>(R.id.reading_back_swipe_edge) } returns mockk<View>()
        val root = mockk<View>(relaxed = true)
        val binding = mockk<ViewBinding> { every { this@mockk.root } returns root }

        activity.applyView(binding)

        verify { WindowCompat.setDecorFitsSystemWindows(window, false) }
    }

    @Test fun readerPaintsStatusInsetBeforeANewInsetsDispatchUsingTheNewActivityTheme() {
        mockkConstructor(TypedValue::class)
        mockkStatic(ViewCompat::class)
        mockkStatic(WindowCompat::class)
        every { WindowCompat.setDecorFitsSystemWindows(any(), any()) } returns Unit
        every { ViewCompat.setOnApplyWindowInsetsListener(any(), any()) } returns Unit
        val activity = themedActivity()
        every { activity.findViewById<View>(R.id.reading_back_swipe_edge) } returns mockk<View>()
        val root = mockk<View>(relaxed = true)
        val binding = mockk<ViewBinding> { every { this@mockk.root } returns root }

        activity.applyView(binding)

        verify { root.setBackgroundColor(NAV_COLOR) }
    }

    @Test fun recreatedReaderRemovesTheFrameworkParentsRetainedInsetPadding() {
        mockkConstructor(TypedValue::class)
        mockkStatic(ViewCompat::class)
        mockkStatic(WindowCompat::class)
        every { WindowCompat.setDecorFitsSystemWindows(any(), any()) } returns Unit
        every { ViewCompat.setOnApplyWindowInsetsListener(any(), any()) } returns Unit
        val activity = themedActivity()
        every { activity.findViewById<View>(R.id.reading_back_swipe_edge) } returns mockk<View>()
        val root = mockk<View>(relaxed = true)
        val content = mockk<LinearLayout>(relaxed = true)
        val frameworkParent = mockk<LinearLayout>(relaxed = true)
        val decor = mockk<LinearLayout>(relaxed = true)
        every { root.parent } returns content
        every { content.parent } returns frameworkParent
        every { content.fitsSystemWindows } returns false
        every { frameworkParent.parent } returns decor
        every { frameworkParent.fitsSystemWindows } returns true
        every { frameworkParent.paddingTop } returns 91
        every { frameworkParent.paddingBottom } returns 88
        every { activity.window.decorView } returns decor
        val binding = mockk<ViewBinding> { every { this@mockk.root } returns root }

        activity.applyView(binding)

        verify { frameworkParent.fitsSystemWindows = false }
        verify { frameworkParent.setPadding(0, 0, 0, 0) }
        verify(exactly = 0) { content.setPadding(any(), any(), any(), any()) }
        verify(exactly = 0) { decor.fitsSystemWindows = any() }
    }

    private fun themedActivity(): Activity {
        val theme = mockk<Resources.Theme>()
        every { theme.resolveAttribute(any(), any(), true) } answers {
            secondArg<TypedValue>().data = if (firstArg<Int>() == android.R.attr.statusBarColor) STATUS_COLOR else NAV_COLOR
            true
        }
        return mockk<Activity>(relaxed = true) { every { this@mockk.theme } returns theme }
    }

    companion object {
        private const val STATUS_COLOR = -15658735
        private const val NAV_COLOR = -14540254
    }
}
