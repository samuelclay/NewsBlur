package com.newsblur.fragment

import android.content.res.Resources
import com.newsblur.R
import com.newsblur.domain.ClassifierScope
import com.newsblur.util.UsageBilling
import java.text.NumberFormat

/** Active filters of one scope in a section's cost breakdown, with that scope's monthly stories. */
internal data class AiCostScopeGroup(
    val scope: String,
    val count: Int,
    val stories: Int,
)

internal data class AiCostSummary(
    val monthly: Double,
    val daily: Double,
    val costPerStory: Double,
    val feedStories: Int,
    val filterCount: Int,
    val groups: List<AiCostScopeGroup>,
)

/**
 * The trainer's monthly AI cost estimate, computed like media/js/newsblur/reader/reader_classifier.js
 * _render_section_cost: each active filter runs on every story its scope gets in a month.
 */
internal object AiClassifierCost {
    /** Null when there are no stories to estimate from, which hides the estimate. */
    fun estimate(
        costPerStory: Double,
        feedStories: Int,
        activeFilterScopes: List<ClassifierScope>,
        storiesForScope: (ClassifierScope) -> Int,
    ): AiCostSummary? {
        var totalStories = 0
        val groups = linkedMapOf<String, AiCostScopeGroup>()
        for (scope in activeFilterScopes) {
            val stories = storiesForScope(scope)
            totalStories += stories
            val kind = if (scope.isFeed) ClassifierScope.FEED else scope.scope
            groups[kind] = groups[kind]?.let { it.copy(count = it.count + 1) } ?: AiCostScopeGroup(kind, 1, stories)
        }
        if (feedStories == 0 && totalStories == 0) return null

        // AiClassifierCost.kt falls back to the feed's own stories when every filter's scope is empty.
        val effectiveStories = if (totalStories != 0) totalStories else feedStories
        val monthly = if (activeFilterScopes.isNotEmpty()) effectiveStories * costPerStory else 0.0
        return AiCostSummary(
            monthly = monthly,
            daily = monthly / 30,
            costPerStory = costPerStory,
            feedStories = feedStories,
            filterCount = activeFilterScopes.size,
            groups = groups.values.toList(),
        )
    }

    /** "$0.12/mo · $0.004/day" */
    fun amounts(
        resources: Resources,
        summary: AiCostSummary,
    ): String =
        resources.getString(R.string.ai_cost_monthly, UsageBilling.formatCost(summary.monthly)) + " · " +
            resources.getString(R.string.ai_cost_daily, UsageBilling.formatCost(summary.daily))

    /** "120 stories/mo × 2 content filters × $0.0004/story", or one part per scope when filters span scopes. */
    fun breakdown(
        resources: Resources,
        summary: AiCostSummary,
        imageFilters: Boolean,
    ): String {
        val costPerStory = resources.getString(R.string.ai_cost_per_story, UsageBilling.formatCost(summary.costPerStory))
        val feedOnly = summary.groups.size == 1 && summary.groups[0].scope == ClassifierScope.FEED
        if (summary.filterCount == 0 || feedOnly) {
            return storiesPerMonth(resources, summary.feedStories) + " × " +
                filters(resources, summary.filterCount, imageFilters) + " × " + costPerStory
        }
        val parts =
            summary.groups.map { group ->
                val message =
                    when (group.scope) {
                        ClassifierScope.FOLDER -> R.string.ai_cost_scope_folder
                        ClassifierScope.GLOBAL -> R.string.ai_cost_scope_global
                        else -> R.string.ai_cost_scope_feed
                    }
                resources.getString(message, group.count, storiesPerMonth(resources, group.stories))
            }
        return parts.joinToString(" + ") + " × " + costPerStory
    }

    private fun storiesPerMonth(
        resources: Resources,
        stories: Int,
    ): String = resources.getQuantityString(R.plurals.ai_cost_stories_per_month, stories, NumberFormat.getIntegerInstance().format(stories))

    private fun filters(
        resources: Resources,
        count: Int,
        imageFilters: Boolean,
    ): String =
        resources.getQuantityString(
            if (imageFilters) R.plurals.ai_cost_image_filters else R.plurals.ai_cost_content_filters,
            count,
            count,
        )
}
