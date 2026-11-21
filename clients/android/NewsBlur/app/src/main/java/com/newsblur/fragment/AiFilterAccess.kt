package com.newsblur.fragment

/** What one of the trainer's AI filter sections (AiClassifierSections.kt) shows. */
internal data class AiSectionStatus(
    // "AI filters are saved but only run on Premium Archive." with a link to upgrade.
    val showsArchiveBanner: Boolean,
    // The test button shows when there is a story to test, and for image filters, images in it.
    val showsTestButton: Boolean,
    val testEnabled: Boolean,
)

/**
 * AiFilterAccess.kt: AI text and image filters are unlimited with Premium Archive, which Pro
 * includes. Any account can save and test them, but they only score stories on Archive or Pro,
 * so other accounts with a filter saved or typed see the Premium Archive banner. Testing a prompt
 * never depends on the account.
 */
internal object AiFilterAccess {
    fun status(
        isArchive: Boolean,
        isPro: Boolean,
        // The section's saved prompt scores. A prompt removed in this trainer is neutral (TrainerScores.kt).
        savedScores: Collection<Int?>,
        typedPrompt: String,
        hasStory: Boolean,
        imagePrompt: Boolean,
        imageCount: Int,
        isTesting: Boolean,
    ): AiSectionStatus {
        val runsFilters = isArchive || isPro
        val hasFilters = savedScores.any { TrainerScores.level(it) != TrainerScores.Level.NEUTRAL } || typedPrompt.isNotBlank()
        return AiSectionStatus(
            showsArchiveBanner = !runsFilters && hasFilters,
            showsTestButton = hasStory && (!imagePrompt || imageCount > 0),
            testEnabled = typedPrompt.isNotBlank() && !isTesting,
        )
    }
}
