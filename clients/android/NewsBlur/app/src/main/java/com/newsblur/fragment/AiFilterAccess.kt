package com.newsblur.fragment

import com.newsblur.network.domain.AiCredits
import com.newsblur.util.AiCreditsStage
import com.newsblur.util.AiCreditsStatus

/** What one of the trainer's AI filter sections (AiClassifierSections.kt) shows. */
internal data class AiSectionStatus(
    // The section's AI credit box (util/AiCreditsStatus.kt), or HIDDEN for none.
    val creditsStage: AiCreditsStage,
    // The test button shows when there is a story to test, and for image filters, images in it.
    val showsTestButton: Boolean,
    val testEnabled: Boolean,
)

/**
 * AiFilterAccess.kt: every paid plan includes AI credits each month, and AI filters run until
 * they're used (apps/analyzer/ai_credits.py). Any account can save and test filters. A paid
 * account always sees its credit meter and any warning or pause, while a free account only hears
 * that filters need a paid plan once it has a filter saved or typed. Testing a prompt never
 * depends on the account.
 */
internal object AiFilterAccess {
    fun status(
        credits: AiCredits?,
        // The section's saved prompt scores. A prompt removed in this trainer is neutral (TrainerScores.kt).
        savedScores: Collection<Int?>,
        typedPrompt: String,
        hasStory: Boolean,
        imagePrompt: Boolean,
        imageCount: Int,
        isTesting: Boolean,
    ): AiSectionStatus {
        val hasFilters = savedScores.any { TrainerScores.level(it) != TrainerScores.Level.NEUTRAL } || typedPrompt.isNotBlank()
        val stage = AiCreditsStatus.stage(credits)
        return AiSectionStatus(
            creditsStage = if (stage == AiCreditsStage.FREE && !hasFilters) AiCreditsStage.HIDDEN else stage,
            showsTestButton = hasStory && (!imagePrompt || imageCount > 0),
            testEnabled = typedPrompt.isNotBlank() && !isTesting,
        )
    }
}
