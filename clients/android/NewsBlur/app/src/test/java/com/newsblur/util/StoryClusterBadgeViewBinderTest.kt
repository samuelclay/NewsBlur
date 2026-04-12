package com.newsblur.util

import com.newsblur.R
import org.junit.Assert.assertEquals
import org.junit.Test

class StoryClusterBadgeViewBinderTest {
    @Test
    fun title_tier_uses_match_label() {
        assertEquals(
            R.string.story_cluster_badge_match,
            StoryClusterBadgeViewBinder.labelRes(StoryClusterDisplayDecision.CLUSTER_TIER_TITLE),
        )
    }

    @Test
    fun unknown_tier_defaults_to_related_label() {
        assertEquals(
            R.string.story_cluster_badge_related,
            StoryClusterBadgeViewBinder.labelRes(null),
        )
    }

    @Test
    fun badge_anchors_to_preview_when_image_is_visible() {
        assertEquals(
            11,
            StoryClusterBadgeViewBinder.endAnchorId(hasPreview = true, previewId = 11, dateId = 17),
        )
    }

    @Test
    fun badge_anchors_to_date_when_image_is_hidden() {
        assertEquals(
            17,
            StoryClusterBadgeViewBinder.endAnchorId(hasPreview = false, previewId = 11, dateId = 17),
        )
    }
}
