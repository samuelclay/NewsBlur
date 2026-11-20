package com.newsblur.util

import android.content.res.Configuration
import androidx.activity.ComponentActivity
import androidx.core.util.Consumer
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkObject
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.Assert.assertTrue
import org.junit.Test

class Test_DeferredSplitTracking {
    @Test
    fun test_folded_launch_keeps_a_listener_for_the_same_activity_unfolding() = withUninstalledRules {
        val activity = mockk<ComponentActivity>(relaxed = true)
        val configurationChanged = slot<Consumer<Configuration>>()
        every { activity.addOnConfigurationChangedListener(capture(configurationChanged)) } just Runs
        every { StorySplitView.installIfWideEnough(activity) } just Runs

        StorySplitView.trackSplit(activity) {}

        // StorySplitView.kt must retry when a manifest-handled resize does not call onCreate again.
        assertTrue("A folded launch discarded its future split tracking", configurationChanged.isCaptured)
        configurationChanged.captured.accept(mockk(relaxed = true))
        verify(exactly = 1) { StorySplitView.installIfWideEnough(activity) }
    }

    @Test
    fun test_unfolding_starts_one_observer_despite_repeated_resizes_and_registration() = withUninstalledRules { rules ->
        val activity = mockk<ComponentActivity>(relaxed = true)
        val configurationChanged = slot<Consumer<Configuration>>()
        val callback = {}
        every { activity.addOnConfigurationChangedListener(capture(configurationChanged)) } just Runs
        every { StorySplitView.installIfWideEnough(activity) } answers { rules.setBoolean(null, true) }

        StorySplitView.trackSplit(activity, callback)
        assertTrue("No configuration callback survives the folded launch", configurationChanged.isCaptured)
        every { StorySplitView["startSplitTracking"](activity, callback) } returns Unit
        configurationChanged.captured.accept(mockk(relaxed = true))
        configurationChanged.captured.accept(mockk(relaxed = true))
        StorySplitView.trackSplit(activity, callback)

        // One observer owns the divider; duplicate collectors would attach overlapping drag targets.
        verify(exactly = 1) { activity.addOnConfigurationChangedListener(any()) }
        verify(exactly = 1) { StorySplitView["startSplitTracking"](activity, callback) }
    }

    private fun withUninstalledRules(block: (java.lang.reflect.Field) -> Unit) {
        val rules = StorySplitView::class.java.getDeclaredField("rulesInstalled").apply { isAccessible = true }
        val original = rules.getBoolean(null)
        mockkObject(StorySplitView, recordPrivateCalls = true)
        mockkStatic(StorySplitView::class)
        try {
            rules.setBoolean(null, false)
            block(rules)
        } finally {
            rules.setBoolean(null, original)
            unmockkStatic(StorySplitView::class)
            unmockkObject(StorySplitView)
        }
    }
}
