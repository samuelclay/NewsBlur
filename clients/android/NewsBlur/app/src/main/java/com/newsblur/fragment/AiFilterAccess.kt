package com.newsblur.fragment

import com.newsblur.domain.Classifier
import com.newsblur.domain.ClassifierScope
import com.newsblur.network.domain.AiCredits
import com.newsblur.util.AiCreditsStage
import com.newsblur.util.AiCreditsStatus

/** What the trainer's AI filter card (AiClassifierSections.kt) shows. */
internal data class AiSectionStatus(
    // The card's AI credit state (util/AiCreditsStatus.kt), or HIDDEN for none.
    val creditsStage: AiCreditsStage,
    // The test button shows when there is a story to test, and in Images mode, images in it.
    val showsTestButton: Boolean,
    val testEnabled: Boolean,
)

/**
 * AiFilterAccess.kt: every paid plan includes AI credits each month, and AI filters run until
 * they're used (apps/analyzer/ai_credits.py). Any account can save and test filters. A paid
 * account always sees its credits and any warning or pause, while a free account only hears
 * that filters need a paid plan once it has an AI filter saved or typed, of either kind. Testing
 * a prompt never depends on the account.
 */
internal object AiFilterAccess {
    fun status(
        credits: AiCredits?,
        // Every saved AI prompt's score, text and image. A prompt removed in this trainer is neutral (TrainerScores.kt).
        savedScores: Collection<Int?>,
        typedPrompt: String,
        hasStory: Boolean,
        // Whether the card's switch is on Images.
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

    /**
     * Adds a typed prompt to the list for the mode it was typed in: a text prompt, or an image
     * prompt, which the save sends as one (Classifier.kt image_prompt). Switching modes later never
     * moves it.
     */
    fun addDraft(
        classifier: Classifier,
        draft: AiPromptDraft,
        scope: ClassifierScope,
    ) {
        val scores = if (draft.imagePrompt) classifier.imagePrompts else classifier.prompts
        scores[draft.prompt] = if (draft.hidden) Classifier.DISLIKE else Classifier.LIKE
        classifier.setPromptScope(draft.imagePrompt, draft.prompt, scope)
    }
}
