package com.newsblur.subscription

import com.newsblur.util.AppConstants

/**
 * ArchiveCardPlan.kt decides what SubscriptionActivity.kt's Premium Archive card offers. Its Listen line can switch
 * between one hour a month (Premium Archive) and ten (Premium Archive Extra); the card shows, buys and manages
 * whichever plan is chosen.
 */
enum class ArchiveListenHours(
    val hours: Int,
    val productId: String,
) {
    ONE(1, AppConstants.PREMIUM_ARCHIVE_SUB_ID),
    TEN(10, AppConstants.PREMIUM_ARCHIVE_EXTRA_SUB_ID),
}

enum class ArchiveCardStatus {
    /** The chosen plan is the account's own. */
    OWNED,

    /**
     * Premium Pro already has more listening than either plan, so in both toggle positions the card says Pro
     * includes it and never offers a purchase, upgrade or manage button.
     */
    INCLUDED_IN_PRO,

    /** One hour, chosen by an account that already has ten. Downgrades go through Play, not this card. */
    INCLUDED_IN_ARCHIVE_EXTRA,
    UPGRADE_FROM_ARCHIVE,
    UPGRADE_FROM_PREMIUM,
    PURCHASE,
}

data class ArchiveCardPlan(
    val showsHoursToggle: Boolean,
    val hours: ArchiveListenHours,
    val status: ArchiveCardStatus,
    /** The position that is the account's own plan, captioned as such on the toggle. */
    val ownedHours: ArchiveListenHours?,
)

/**
 * The toggle needs Play to sell Premium Archive Extra, or an account that already has it. Pro sees it under the same
 * rule, so it can compare both plans, though its subscription already includes either one.
 * Until someone touches it, it sits on the account's own plan: ten hours for Archive Extra, one for everyone else.
 * Pro is on neither plan, so its toggle starts on one hour and neither position is captioned as its own.
 */
fun archiveCardPlan(
    isPremium: Boolean,
    isArchive: Boolean,
    isArchiveExtra: Boolean,
    isPro: Boolean,
    extraOffered: Boolean,
    chosenHours: ArchiveListenHours?,
): ArchiveCardPlan {
    val ownsExtra = isArchiveExtra && !isPro
    val showsHoursToggle = extraOffered || ownsExtra
    val ownedHours =
        when {
            isPro -> null
            ownsExtra -> ArchiveListenHours.TEN
            isArchive -> ArchiveListenHours.ONE
            else -> null
        }
    val hours = if (showsHoursToggle) chosenHours ?: ownedHours ?: ArchiveListenHours.ONE else ArchiveListenHours.ONE
    val status =
        when {
            isPro -> ArchiveCardStatus.INCLUDED_IN_PRO
            ownsExtra ->
                if (hours == ArchiveListenHours.TEN) ArchiveCardStatus.OWNED else ArchiveCardStatus.INCLUDED_IN_ARCHIVE_EXTRA
            isArchive ->
                if (hours == ArchiveListenHours.ONE) ArchiveCardStatus.OWNED else ArchiveCardStatus.UPGRADE_FROM_ARCHIVE
            isPremium -> ArchiveCardStatus.UPGRADE_FROM_PREMIUM
            else -> ArchiveCardStatus.PURCHASE
        }
    return ArchiveCardPlan(showsHoursToggle, hours, status, ownedHours)
}
