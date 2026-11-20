package com.newsblur.fragment

import com.newsblur.domain.Classifier
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// Test_AiFilterAccess.kt: AI filters only score stories on Premium Archive or Pro, so the trainer's
// AI sections (AiClassifierSections.kt) tell any other account that has one saved or typed, and
// testing a prompt works the same on every account.
class Test_AiFilterAccess {
    private fun status(
        isArchive: Boolean = false,
        isPro: Boolean = false,
        savedScores: Collection<Int?> = emptyList(),
        typedPrompt: String = "",
        imagePrompt: Boolean = false,
        imageCount: Int = 0,
    ) = AiFilterAccess.status(
        isArchive = isArchive,
        isPro = isPro,
        savedScores = savedScores,
        typedPrompt = typedPrompt,
        hasStory = true,
        imagePrompt = imagePrompt,
        imageCount = imageCount,
        isTesting = false,
    )

    @Test
    fun test_saved_filters_on_an_account_without_archive_show_the_banner() {
        assertTrue(status(savedScores = listOf(Classifier.LIKE)).showsArchiveBanner)
        assertTrue("A hidden filter is saved too", status(savedScores = listOf(Classifier.DISLIKE)).showsArchiveBanner)
        assertTrue("A filter being typed will be saved", status(typedPrompt = "Apple rumors").showsArchiveBanner)
    }

    @Test
    fun test_only_removed_filters_show_no_banner() {
        // TrainerScores.kt leaves a prompt removed in this trainer listed with a neutral or null score.
        assertFalse(status(savedScores = listOf(Classifier.CLEAR_LIKE, null)).showsArchiveBanner)
        assertFalse(status().showsArchiveBanner)
    }

    @Test
    fun test_archive_and_pro_accounts_never_see_the_banner() {
        val saved = listOf(Classifier.LIKE, Classifier.DISLIKE)

        assertFalse(status(isArchive = true, savedScores = saved, typedPrompt = "Charts").showsArchiveBanner)
        assertFalse("Pro includes Archive", status(isPro = true, savedScores = saved, typedPrompt = "Charts").showsArchiveBanner)
    }

    @Test
    fun test_testing_a_prompt_does_not_depend_on_the_account() {
        for (imagePrompt in listOf(false, true)) {
            val archive = status(isArchive = true, typedPrompt = "Charts", imagePrompt = imagePrompt, imageCount = 2)
            val free = status(typedPrompt = "Charts", imagePrompt = imagePrompt, imageCount = 2)

            assertTrue(free.showsTestButton)
            assertTrue(free.testEnabled)
            assertEquals(archive.copy(showsArchiveBanner = true), free)
        }
    }
}
