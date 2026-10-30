package com.newsblur.fragment

import com.newsblur.domain.Classifier

/**
 * How the trainer capsules in IntelTrainerSections.kt change a classifier, following
 * clients/ios/Classes/TrainerView.swift and the toggle*Classifier methods in NewsBlurAppDelegate.m.
 * Each result is the Classifier.kt value the trainer saves, the same value util/UIUtils.java
 * setupIntelDialogRow stored for that choice, so /classifier/save gets the same parameters.
 */
object TrainerScores {
    enum class Level { NEUTRAL, LIKE, DISLIKE, SUPER_DISLIKE }

    /** What tapping a capsule's body does, which differs by classifier on iOS. */
    enum class TapStyle {
        /** Authors, tags and the publisher: neutral, like, dislike, then neutral again. */
        CYCLE,

        /** Titles, text, URLs and every regex: a like turns off, anything else becomes a like. */
        TOGGLE_LIKE,
    }

    /** A removed opinion (CLEAR_LIKE and the like) shows as neutral until the trainer saves. */
    @JvmStatic
    fun level(value: Int?): Level =
        when (value) {
            Classifier.LIKE -> Level.LIKE
            Classifier.DISLIKE -> Level.DISLIKE
            Classifier.SUPER_DISLIKE -> Level.SUPER_DISLIKE
            else -> Level.NEUTRAL
        }

    @JvmStatic
    fun afterTap(
        style: TapStyle,
        current: Int?,
        original: Int?,
    ): Int? =
        when (style) {
            TapStyle.CYCLE ->
                when (level(current)) {
                    Level.NEUTRAL -> Classifier.LIKE
                    Level.LIKE -> Classifier.DISLIKE
                    Level.DISLIKE, Level.SUPER_DISLIKE -> neutral(original)
                }
            TapStyle.TOGGLE_LIKE -> if (level(current) == Level.LIKE) neutral(original) else Classifier.LIKE
        }

    /** The inline thumbs down turns a dislike off, or anything else into a dislike. */
    @JvmStatic
    fun afterDislike(
        current: Int?,
        original: Int?,
    ): Int? = if (level(current) == Level.DISLIKE) neutral(original) else Classifier.DISLIKE

    /** The inline double thumbs down turns a super dislike off, or anything else into one. */
    @JvmStatic
    fun afterSuperDislike(
        current: Int?,
        original: Int?,
    ): Int? = if (level(current) == Level.SUPER_DISLIKE) neutral(original) else Classifier.SUPER_DISLIKE

    /**
     * Back to no opinion. A saved opinion is removed with the matching CLEAR value, as the old
     * clear button did, and anything else goes back to what the trainer opened with, so turning
     * an untrained capsule on and off again sends nothing.
     */
    @JvmStatic
    fun neutral(original: Int?): Int? =
        when (original) {
            Classifier.LIKE -> Classifier.CLEAR_LIKE
            Classifier.DISLIKE -> Classifier.CLEAR_DISLIKE
            Classifier.SUPER_DISLIKE -> Classifier.CLEAR_SUPER_DISLIKE
            else -> original
        }

    /** Stores [value] for [key], where null takes the key out as if it was never trained. */
    @JvmStatic
    fun store(
        scores: MutableMap<String, Int>,
        key: String,
        value: Int?,
    ) {
        if (value == null) scores.remove(key) else scores[key] = value
    }
}
