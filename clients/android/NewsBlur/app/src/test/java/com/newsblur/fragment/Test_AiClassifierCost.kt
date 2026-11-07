package com.newsblur.fragment

import android.content.res.Resources
import com.newsblur.R
import com.newsblur.domain.ClassifierScope
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

// Test_AiClassifierCost.kt: the trainer's monthly AI estimate matches
// media/js/newsblur/reader/reader_classifier.js _render_section_cost.
class Test_AiClassifierCost {
    private val storiesByScope =
        mapOf(
            ClassifierScope.FEED_SCOPE to 120,
            ClassifierScope.folder("Tech") to 900,
            ClassifierScope.GLOBAL_SCOPE to 3000,
        )

    private fun estimate(
        feedStories: Int,
        vararg scopes: ClassifierScope,
    ) = AiClassifierCost.estimate(0.001, feedStories, scopes.toList()) { storiesByScope[it] ?: 0 }

    @Test
    fun test_no_filters_show_a_zero_estimate_for_the_feed() {
        val summary = estimate(120)!!

        assertEquals(0.0, summary.monthly, 0.0)
        assertEquals(0, summary.filterCount)
    }

    @Test
    fun test_feed_filters_multiply_the_feed_stories() {
        val summary = estimate(120, ClassifierScope.FEED_SCOPE, ClassifierScope.FEED_SCOPE)!!

        assertEquals(0.24, summary.monthly, 1e-9)
        assertEquals(0.008, summary.daily, 1e-9)
        assertEquals(listOf(AiCostScopeGroup(ClassifierScope.FEED, 2, 120)), summary.groups)
    }

    @Test
    fun test_scoped_filters_use_each_scope_stories() {
        val summary = estimate(120, ClassifierScope.FEED_SCOPE, ClassifierScope.GLOBAL_SCOPE, ClassifierScope.folder("Tech"))!!

        assertEquals((120 + 3000 + 900) * 0.001, summary.monthly, 1e-9)
        assertEquals(listOf(ClassifierScope.FEED, ClassifierScope.GLOBAL, ClassifierScope.FOLDER), summary.groups.map { it.scope })
    }

    @Test
    fun test_nothing_to_estimate_hides_the_estimate() {
        assertNull(estimate(0))
        assertNull(estimate(0, ClassifierScope.folder("Empty")))
    }

    @Test
    fun test_breakdown_text_follows_the_web_formats() {
        val resources = mockk<Resources>()
        every { resources.getString(R.string.ai_cost_per_story, any()) } answers { "${(secondArg<Array<Any>>())[0]}/story" }
        every { resources.getQuantityString(R.plurals.ai_cost_stories_per_month, any(), any()) } answers { "${(thirdArg<Array<Any>>())[0]} stories/mo" }
        every { resources.getQuantityString(R.plurals.ai_cost_content_filters, any(), any()) } answers { "${secondArg<Int>()} content filters" }
        every { resources.getQuantityString(R.plurals.ai_cost_image_filters, any(), any()) } answers { "${secondArg<Int>()} image filters" }
        every { resources.getString(R.string.ai_cost_scope_feed, any(), any()) } answers {
            val args = secondArg<Array<Any>>()
            "${args[0]} on this site (${args[1]})"
        }
        every { resources.getString(R.string.ai_cost_scope_global, any(), any()) } answers {
            val args = secondArg<Array<Any>>()
            "${args[0]} on all sites (${args[1]})"
        }

        assertEquals(
            "120 stories/mo × 2 content filters × $0.0010/story",
            AiClassifierCost.breakdown(resources, estimate(120, ClassifierScope.FEED_SCOPE, ClassifierScope.FEED_SCOPE)!!, imageFilters = false),
        )
        assertEquals(
            "120 stories/mo × 0 image filters × $0.0010/story",
            AiClassifierCost.breakdown(resources, estimate(120)!!, imageFilters = true),
        )
        assertEquals(
            "1 on this site (120 stories/mo) + 1 on all sites (3,000 stories/mo) × $0.0010/story",
            AiClassifierCost.breakdown(resources, estimate(120, ClassifierScope.FEED_SCOPE, ClassifierScope.GLOBAL_SCOPE)!!, imageFilters = false),
        )
    }
}
