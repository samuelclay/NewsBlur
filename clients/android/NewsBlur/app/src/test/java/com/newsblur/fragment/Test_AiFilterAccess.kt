package com.newsblur.fragment

import com.newsblur.domain.Classifier
import com.newsblur.network.domain.AiCredits
import com.newsblur.util.AiCreditsStage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

// Test_AiFilterAccess.kt: AI filters run on a paid plan's monthly AI credits. The trainer's AI
// sections (AiClassifierSections.kt) only tell a free account about plans once it has a filter
// saved or typed, always show a paid account its credits, show nothing on a server that counts
// none, and test a prompt the same way on every account.
class Test_AiFilterAccess {
    private val free = AiCredits(included = 0, isPaused = true, pauseReason = "plan")
    private val premium = AiCredits(included = 5, used = 1.0)

    private fun status(
        credits: AiCredits? = free,
        savedScores: Collection<Int?> = emptyList(),
        typedPrompt: String = "",
        imagePrompt: Boolean = false,
        imageCount: Int = 0,
    ) = AiFilterAccess.status(
        credits = credits,
        savedScores = savedScores,
        typedPrompt = typedPrompt,
        hasStory = true,
        imagePrompt = imagePrompt,
        imageCount = imageCount,
        isTesting = false,
    )

    @Test
    fun test_a_free_account_with_a_filter_hears_about_plans() {
        assertEquals(AiCreditsStage.FREE, status(savedScores = listOf(Classifier.LIKE)).creditsStage)
        assertEquals("A hidden filter is saved too", AiCreditsStage.FREE, status(savedScores = listOf(Classifier.DISLIKE)).creditsStage)
        assertEquals("A filter being typed will be saved", AiCreditsStage.FREE, status(typedPrompt = "Apple rumors").creditsStage)
    }

    @Test
    fun test_a_free_account_without_filters_sees_nothing() {
        // TrainerScores.kt leaves a prompt removed in this trainer listed with a neutral or null score.
        assertEquals(AiCreditsStage.HIDDEN, status(savedScores = listOf(Classifier.CLEAR_LIKE, null)).creditsStage)
        assertEquals(AiCreditsStage.HIDDEN, status().creditsStage)
    }

    @Test
    fun test_a_paid_account_always_sees_its_credits() {
        assertEquals("Before any filter, to see what one would spend", AiCreditsStage.RUNNING, status(credits = premium).creditsStage)
        val paused = premium.copy(used = 5.0, isPaused = true, pauseReason = "credits")
        assertEquals(AiCreditsStage.PAUSED_CREDITS, status(credits = paused).creditsStage)
    }

    @Test
    fun test_a_server_that_counts_no_credits_shows_none() {
        assertEquals(AiCreditsStage.HIDDEN, status(credits = AiCredits(isUnlimited = true), typedPrompt = "Charts").creditsStage)
        assertEquals("Not synced yet", AiCreditsStage.HIDDEN, status(credits = null, typedPrompt = "Charts").creditsStage)
    }

    @Test
    fun test_testing_a_prompt_does_not_depend_on_the_account() {
        for (imagePrompt in listOf(false, true)) {
            val paid = status(credits = premium, typedPrompt = "Charts", imagePrompt = imagePrompt, imageCount = 2)
            val free = status(typedPrompt = "Charts", imagePrompt = imagePrompt, imageCount = 2)

            assertTrue(free.showsTestButton)
            assertTrue(free.testEnabled)
            assertEquals(paid.copy(creditsStage = AiCreditsStage.FREE), free)
        }
    }
}
