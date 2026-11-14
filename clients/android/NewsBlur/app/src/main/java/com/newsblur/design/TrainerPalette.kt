package com.newsblur.design

import com.newsblur.util.PrefConstants.ThemeValue

/**
 * Colors for the intelligence trainers (fragment/IntelTrainerSections.kt, view/TrainerCapsuleView.kt
 * and the AI sections in fragment/AiClassifierSections.kt), one set per theme. The values follow
 * clients/ios/Classes/TrainerView.swift, TrainerCapsule.swift, TrainerWord.swift and
 * TrainerRegexInput.swift: Light and Sepia match iOS, Dark matches iOS Medium and Black matches
 * iOS Dark on a true black sheet. A new theme only needs a new branch in colors().
 */
object TrainerPalette {
    data class Colors(
        val sheetBackground: Int,
        val cardBackground: Int,
        val textPrimary: Int,
        val textSecondary: Int,
        val dragHandle: Int,
        // The colored "like" and "dislike" in the trainer's question.
        val questionLike: Int,
        val questionDislike: Int,
        // TrainerWord.swift: the story title's tappable words.
        val wordBackground: Int,
        val wordText: Int,
        // TrainerCapsule.swift: a classifier capsule without an opinion.
        val capsuleNeutral: Int,
        val capsuleNeutralText: Int,
        val capsuleNeutralLabel: Int,
        val capsuleNeutralIcon: Int,
        val capsuleDivider: Int,
        // The inline thumbs down buttons on a neutral capsule.
        val dislikeIcon: Int,
        val superDislikeIcon: Int,
        // TrainerRegexInput.swift: the Exact phrase | Regex segmented control.
        val segmentTrack: Int,
        val segmentSelected: Int,
        val segmentSelectedText: Int,
        val segmentText: Int,
        // TrainerCapsule.swift regexBody: a regex capsule without an opinion.
        val regexNeutral: Int,
        val regexText: Int,
        val fieldBackground: Int,
        val fieldBorder: Int,
        // TrainerAIPromptSection.swift costBackground: boxes set into a card, like the AI cost estimate.
        val insetBackground: Int,
        val clearIcon: Int,
        // ScopeToggleView.swift: the site, folder and global icons.
        val scopeInactive: Int,
        val scopeFeedActive: Int,
        // TrainerRegexInput.swift validation badges.
        val validBackground: Int,
        val validText: Int,
        val validBorder: Int,
        val noMatchBackground: Int,
        val noMatchText: Int,
        val noMatchBorder: Int,
        val errorBackground: Int,
        val errorText: Int,
        val errorBorder: Int,
        // Capsules with an opinion are the same in every theme.
        val capsuleLike: Int = 0xFF008000.toInt(),
        val capsuleDislike: Int = 0xFFFF3B30.toInt(),
        val capsuleSuperDislike: Int = 0xFF6B0001.toInt(),
        val capsuleActiveText: Int = 0xFFFFFFFF.toInt(),
        val capsuleActiveLabel: Int = 0xFFD9D9D9.toInt(),
        val regexAccent: Int = 0xFF7B68EE.toInt(),
        val regexNeutralIcon: Int = 0xFF7986CB.toInt(),
        // TrainerAIPromptSection.swift: the natural language sections' icons and CONTENT badge.
        val promptAccent: Int = 0xFF5A6BD9.toInt(),
        val scopeFolderActive: Int = 0xFF3B82F6.toInt(),
        val scopeGlobalActive: Int = 0xFF8B5CF6.toInt(),
    )

    private val light =
        Colors(
            sheetBackground = 0xFFF0F2ED.toInt(),
            cardBackground = 0xFFFFFFFF.toInt(),
            textPrimary = 0xFF1C1C1E.toInt(),
            textSecondary = 0xFF6E6E73.toInt(),
            dragHandle = 0xFFC8CAC4.toInt(),
            questionLike = 0xFF34C759.toInt(),
            questionDislike = 0xFFFF3B30.toInt(),
            wordBackground = 0xFFF2F2F2.toInt(),
            wordText = 0xFF1A1A1A.toInt(),
            capsuleNeutral = 0xFFD8D8D8.toInt(),
            capsuleNeutralText = 0xFF333333.toInt(),
            capsuleNeutralLabel = 0xFF737373.toInt(),
            capsuleNeutralIcon = 0xFFFFFFFF.toInt(),
            capsuleDivider = 0xFFBBBBBB.toInt(),
            dislikeIcon = 0xFFA90103.toInt(),
            superDislikeIcon = 0xFF6B0001.toInt(),
            segmentTrack = 0xFFE8E8E8.toInt(),
            segmentSelected = 0xFFFFFFFF.toInt(),
            segmentSelectedText = 0xFF333333.toInt(),
            segmentText = 0xFF666666.toInt(),
            regexNeutral = 0xFFE8EAF6.toInt(),
            regexText = 0xFF333333.toInt(),
            fieldBackground = 0xFFFFFFFF.toInt(),
            fieldBorder = 0xFFC7C7CC.toInt(),
            insetBackground = 0xFFF2F4EF.toInt(),
            clearIcon = 0xFFAEAEB2.toInt(),
            scopeInactive = 0xFF8C8C8C.toInt(),
            scopeFeedActive = 0xFF595959.toInt(),
            validBackground = 0xFFE8F5E9.toInt(),
            validText = 0xFF2E7D32.toInt(),
            validBorder = 0xFFA5D6A7.toInt(),
            noMatchBackground = 0xFFF5F5F5.toInt(),
            noMatchText = 0xFF757575.toInt(),
            noMatchBorder = 0xFFE0E0E0.toInt(),
            errorBackground = 0xFFFFEBEE.toInt(),
            errorText = 0xFFC62828.toInt(),
            errorBorder = 0xFFEF9A9A.toInt(),
        )

    private val sepia =
        light.copy(
            sheetBackground = 0xFFF3E2CB.toInt(),
            cardBackground = 0xFFFAF5ED.toInt(),
            textPrimary = 0xFF3C3226.toInt(),
            textSecondary = 0xFF8B7B6B.toInt(),
            dragHandle = 0xFFD4C8B8.toInt(),
            wordBackground = 0xFFEADFD0.toInt(),
            wordText = 0xFF3C3226.toInt(),
            capsuleNeutral = 0xFFD0C4B4.toInt(),
            capsuleNeutralText = 0xFF3C3226.toInt(),
            capsuleNeutralLabel = 0xFF7A6A5A.toInt(),
            capsuleDivider = 0xFFB0A090.toInt(),
            segmentTrack = 0xFFE0D8C8.toInt(),
            segmentSelected = 0xFFFAF5ED.toInt(),
            segmentSelectedText = 0xFF3C3226.toInt(),
            segmentText = 0xFF8B7B6B.toInt(),
            regexNeutral = 0xFFE8DFD0.toInt(),
            regexText = 0xFF3C3226.toInt(),
            fieldBackground = 0xFFFFFBF5.toInt(),
            fieldBorder = 0xFFD4C8B8.toInt(),
            insetBackground = 0xFFF3E9DA.toInt(),
            clearIcon = 0xFFB0A090.toInt(),
        )

    private val dark =
        Colors(
            sheetBackground = 0xFF2C2C2E.toInt(),
            cardBackground = 0xFF3A3A3C.toInt(),
            textPrimary = 0xFFF2F2F7.toInt(),
            textSecondary = 0xFFAEAEB2.toInt(),
            dragHandle = 0xFF5A5A5E.toInt(),
            questionLike = 0xFF30D158.toInt(),
            questionDislike = 0xFFFF453A.toInt(),
            wordBackground = 0xFF595959.toInt(),
            wordText = 0xFFE0E0E0.toInt(),
            capsuleNeutral = 0xFF595959.toInt(),
            capsuleNeutralText = 0xFFE0E0E0.toInt(),
            capsuleNeutralLabel = 0xFFB0B0B0.toInt(),
            capsuleNeutralIcon = 0xFFFFFFFF.toInt(),
            capsuleDivider = 0xFF777777.toInt(),
            dislikeIcon = 0xFFE87272.toInt(),
            superDislikeIcon = 0xFFFF6B6B.toInt(),
            segmentTrack = 0xFF2C2C2E.toInt(),
            segmentSelected = 0xFF4A4A4C.toInt(),
            segmentSelectedText = 0xFFE0E0E0.toInt(),
            segmentText = 0xFF999999.toInt(),
            regexNeutral = 0xFF2A2C3E.toInt(),
            regexText = 0xFFE0E0E0.toInt(),
            fieldBackground = 0xFF2C2C2E.toInt(),
            fieldBorder = 0xFF555555.toInt(),
            insetBackground = 0xFF2C2C2E.toInt(),
            clearIcon = 0xFF8E8E93.toInt(),
            scopeInactive = 0xFF9A9A9A.toInt(),
            scopeFeedActive = 0xFFE0E0E0.toInt(),
            validBackground = 0xFF1A2E1A.toInt(),
            validText = 0xFF7ECE72.toInt(),
            validBorder = 0xFF2E7D32.toInt(),
            noMatchBackground = 0xFF2C2C2E.toInt(),
            noMatchText = 0xFFAEAEB2.toInt(),
            noMatchBorder = 0xFF48484A.toInt(),
            errorBackground = 0xFF2E1A1A.toInt(),
            errorText = 0xFFEF9A9A.toInt(),
            errorBorder = 0xFF6D3A3A.toInt(),
            capsuleDislike = 0xFFFF453A.toInt(),
        )

    private val black =
        dark.copy(
            sheetBackground = 0xFF000000.toInt(),
            cardBackground = 0xFF1C1C1E.toInt(),
            dragHandle = 0xFF48484A.toInt(),
            wordBackground = 0xFF3A3A3C.toInt(),
            capsuleNeutral = 0xFF48484A.toInt(),
            segmentTrack = 0xFF000000.toInt(),
            segmentSelected = 0xFF3A3A3C.toInt(),
            fieldBackground = 0xFF000000.toInt(),
            fieldBorder = 0xFF444444.toInt(),
            insetBackground = 0xFF000000.toInt(),
            noMatchBackground = 0xFF1C1C1E.toInt(),
            noMatchBorder = 0xFF3A3A3C.toInt(),
        )

    @JvmStatic
    fun colors(theme: ThemeValue): Colors =
        when (theme) {
            ThemeValue.SEPIA -> sepia
            ThemeValue.DARK -> dark
            ThemeValue.BLACK -> black
            else -> light
        }
}
