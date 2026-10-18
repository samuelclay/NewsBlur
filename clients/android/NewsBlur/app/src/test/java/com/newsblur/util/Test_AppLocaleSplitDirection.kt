package com.newsblur.util

import android.content.res.Configuration
import android.util.DisplayMetrics
import android.view.View
import androidx.window.WindowSdkExtensions
import androidx.window.embedding.ActivityEmbeddingController
import androidx.window.embedding.RuleController
import androidx.window.embedding.SplitAttributes
import androidx.window.embedding.SplitAttributesCalculatorParams
import androidx.window.embedding.SplitController
import com.newsblur.NbApplication
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkObject
import io.mockk.mockkStatic
import io.mockk.slot
import io.mockk.unmockkObject
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Test

class Test_AppLocaleSplitDirection {
    @Test
    fun test_arabic_app_uses_explicit_rtl_even_when_parent_window_is_english() = withEmbedding { app, config, calculator, _ ->
        every { config.layoutDirection } returns View.LAYOUT_DIRECTION_RTL
        StorySplitView.installIfWideEnough(app)

        // Samsung's embedding parent configuration stays English when LanguageSettings.kt selects Arabic.
        assertEquals(SplitAttributes.LayoutDirection.RIGHT_TO_LEFT, calculator()(params("story_list_reader")).layoutDirection)
        assertEquals(SplitAttributes.LayoutDirection.RIGHT_TO_LEFT, calculator()(params("empty_reader")).layoutDirection)
        assertEquals(SplitAttributes.LayoutDirection.LEFT_TO_RIGHT, calculator()(params("story_list_feeds")).layoutDirection)
    }

    @Test
    fun test_language_change_reorders_existing_splits_without_reinstalling_the_calculator() = withEmbedding { app, config, calculator, embedding ->
        every { config.layoutDirection } returns View.LAYOUT_DIRECTION_LTR
        StorySplitView.installIfWideEnough(app)

        every { config.layoutDirection } returns View.LAYOUT_DIRECTION_RTL
        StorySplitView.installIfWideEnough(app)
        StorySplitView.installIfWideEnough(app)

        assertEquals(SplitAttributes.LayoutDirection.RIGHT_TO_LEFT, calculator()(params("story_list_reader")).layoutDirection)
        verify(exactly = 1) { embedding.invalidateVisibleActivityStacks() }

        every { config.layoutDirection } returns View.LAYOUT_DIRECTION_LTR
        StorySplitView.installIfWideEnough(app)
        assertEquals(SplitAttributes.LayoutDirection.LEFT_TO_RIGHT, calculator()(params("story_list_reader")).layoutDirection)
        assertEquals(SplitAttributes.LayoutDirection.RIGHT_TO_LEFT, calculator()(params("story_list_feeds")).layoutDirection)
        verify(exactly = 2) { embedding.invalidateVisibleActivityStacks() }
    }

    private fun params(tag: String): SplitAttributesCalculatorParams = mockk(relaxed = true) {
        every { splitRuleTag } returns tag
        every { areDefaultConstraintsSatisfied } returns true
        every { parentConfiguration.layoutDirection } returns View.LAYOUT_DIRECTION_LTR
        every { parentWindowMetrics.bounds.width() } returns 1200
        every { defaultSplitAttributes } returns SplitAttributes.Builder()
            .setLayoutDirection(SplitAttributes.LayoutDirection.LOCALE).build()
    }

    private fun withEmbedding(block: (NbApplication, Configuration, () -> ((SplitAttributesCalculatorParams) -> SplitAttributes), ActivityEmbeddingController) -> Unit) {
        val rules = StorySplitView::class.java.getDeclaredField("rulesInstalled").apply { isAccessible = true }
        val support = StorySplitView::class.java.getDeclaredField("readerFullscreenSupported").apply { isAccessible = true }
        val direction = StorySplitView::class.java.getDeclaredField("paneLayoutDirection").apply { isAccessible = true }
        val originalRules = rules.getBoolean(null)
        val originalSupport = support.getBoolean(null)
        val originalDirection = direction.getInt(null)
        mockkObject(StorySplitView, recordPrivateCalls = true)
        mockkStatic(StorySplitView::class)
        mockkObject(SplitController.Companion, RuleController.Companion, ActivityEmbeddingController.Companion, WindowSdkExtensions.Companion, LanguageSettings)
        try {
            rules.setBoolean(null, false)
            val config = mockk<Configuration>(relaxed = true).apply { smallestScreenWidthDp = 800 }
            val metrics = mockk<DisplayMetrics>().apply { density = 1f }
            val app = mockk<NbApplication>(relaxed = true)
            every { app.applicationContext } returns app
            every { app.resources.configuration } returns config
            every { app.resources.displayMetrics } returns metrics
            every { app.prefsRepo.get().getFeedListWidthRatio() } returns 0.4f
            every { app.prefsRepo.get().getStoryListSplitRatio() } returns 0.4f
            every { LanguageSettings.localizedContext(app) } returns app
            every { StorySplitView.buildRules(app) } returns emptySet()
            every { StorySplitView["isResizingPanes"]() } returns false
            val controller = mockk<SplitController>(relaxed = true)
            val embedding = mockk<ActivityEmbeddingController>(relaxed = true)
            every { SplitController.getInstance(app) } returns controller
            every { RuleController.getInstance(app) } returns mockk(relaxed = true)
            every { ActivityEmbeddingController.getInstance(app) } returns embedding
            every { controller.splitSupportStatus } returns SplitController.SplitSupportStatus.SPLIT_AVAILABLE
            every { WindowSdkExtensions.getInstance().extensionVersion } returns 3
            val calculator = slot<(SplitAttributesCalculatorParams) -> SplitAttributes>()
            every { controller.setSplitAttributesCalculator(capture(calculator)) } returns Unit
            block(app, config, { calculator.captured }, embedding)
            verify(exactly = 1) { controller.setSplitAttributesCalculator(any()) }
        } finally {
            rules.setBoolean(null, originalRules)
            support.setBoolean(null, originalSupport)
            direction.setInt(null, originalDirection)
            unmockkObject(SplitController.Companion, RuleController.Companion, ActivityEmbeddingController.Companion, WindowSdkExtensions.Companion, LanguageSettings)
            unmockkStatic(StorySplitView::class)
            unmockkObject(StorySplitView)
        }
    }
}
