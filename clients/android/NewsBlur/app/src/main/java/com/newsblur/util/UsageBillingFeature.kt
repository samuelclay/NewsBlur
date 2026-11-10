package com.newsblur.util

/**
 * UsageBillingFeature.kt: the one switch for every natural language classifier billing entry
 * point in the app.
 *
 * Held for this release. Usage billing runs through Stripe, and Google Play's and the App Store's
 * rules on payment outside their own billing differ outside the US, so the app names no purchase
 * path until that's settled. While [ENABLED] is false:
 * - the Premium screen (play/.../SubscriptionActivity.kt) hides its billing card,
 * - the trainer's cost box (fragment/AiClassifierSections.kt) keeps its estimate but has no
 *   billing button,
 * - the trainer's banners keep their statements but lose their links, and an account without
 *   billing sees a neutral line instead of a call to set it up,
 * - activity/UsageBillingActivity.kt closes as soon as anything opens it, including its
 *   <socialCallbackScheme>://usage-billing deep link, so it never starts a Stripe session.
 *
 * The billing code and its tests stay in place, so setting [ENABLED] back to true restores all of it.
 * The functions below take the switch as a parameter so tests cover both states.
 */
object UsageBillingFeature {
    const val ENABLED = false

    /** Whether the Premium screen shows its natural language classifier billing card. */
    @JvmStatic
    fun showsPremiumCard(enabled: Boolean = ENABLED): Boolean = enabled

    /** Whether UsageBillingActivity.kt may open, from a button, a banner link or its deep link. */
    @JvmStatic
    fun opensBillingScreen(enabled: Boolean = ENABLED): Boolean = enabled

    /** The billing button the trainer's cost box offers, or NONE for no button. */
    @JvmStatic
    fun costBoxAction(
        billing: UsageBillingState,
        enabled: Boolean = ENABLED,
    ): UsageBillingAction = if (enabled) billing.action else UsageBillingAction.NONE

    /**
     * The trainer section's banner, following media/js/newsblur/reader/reader_classifier.js
     * show_limit_reached_banner and make_ai_billing_banner while billing is on.
     */
    @JvmStatic
    fun banner(
        limitReached: Boolean,
        hasPrompts: Boolean,
        canUseAiClassifiers: Boolean,
        enabled: Boolean = ENABLED,
    ): UsageBillingBanner =
        when {
            limitReached -> if (enabled) UsageBillingBanner.LIMIT_REACHED_WITH_LINK else UsageBillingBanner.LIMIT_REACHED
            hasPrompts && !canUseAiClassifiers -> if (enabled) UsageBillingBanner.SET_UP_BILLING else UsageBillingBanner.NOT_ACTIVE
            else -> UsageBillingBanner.NONE
        }
}

enum class UsageBillingBanner(
    // Whether the banner links to UsageBillingActivity.kt.
    val linksToBilling: Boolean,
) {
    NONE(false),

    // "Monthly spending limit reached." and why classifiers are paused.
    LIMIT_REACHED(false),

    // LIMIT_REACHED and "Increase or remove your limit".
    LIMIT_REACHED_WITH_LINK(true),

    // "AI filters are saved but won’t run until you set up usage-based billing."
    SET_UP_BILLING(true),

    // "Natural language filters aren’t active on this account."
    NOT_ACTIVE(false),
}
