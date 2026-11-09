package com.newsblur.domain

import org.junit.Assert.assertEquals
import org.junit.Test

// Test_StoryIntelligencePriority.kt: Story.Intelligence.calcTotalIntel must combine AI prompt
// matches the same way apps/analyzer/models.py:compute_story_score does. An AI match is a like
// or a dislike like any other, and a manual super dislike (-2) beats every like.
class Test_StoryIntelligencePriority {
    private fun intelligence(
        feed: Int = 0,
        author: Int = 0,
        title: Int = 0,
        prompt: Int = 0,
    ) = Story.Intelligence().apply {
        intelligenceFeed = feed
        intelligenceAuthors = author
        intelligenceTitle = title
        intelligencePrompt = prompt
    }

    @Test fun test_ai_focus_match_outranks_disliked_author() {
        assertEquals(1, intelligence(feed = 1, author = -1, prompt = 1).calcTotalIntel())
    }

    @Test fun test_super_disliked_author_outranks_ai_focus_match() {
        assertEquals(-2, intelligence(feed = 1, author = -2, prompt = 1).calcTotalIntel())
    }

    @Test fun test_super_dislike_stays_super_alongside_ai_hidden_match() {
        assertEquals(-2, intelligence(author = -2, prompt = -1).calcTotalIntel())
    }

    @Test fun test_liked_title_beats_ai_hidden_match() {
        assertEquals(1, intelligence(title = 1, prompt = -1).calcTotalIntel())
    }

    @Test fun test_ai_hidden_match_alone_hides_the_story() {
        assertEquals(-1, intelligence(feed = 1, prompt = -1).calcTotalIntel())
    }

    @Test fun test_unmatched_prompt_changes_nothing() {
        assertEquals(-1, intelligence(author = -1, prompt = 0).calcTotalIntel())
        assertEquals(1, intelligence(feed = 1).calcTotalIntel())
    }
}
