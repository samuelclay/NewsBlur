package com.newsblur.util

import com.newsblur.network.domain.AiCredits

/**
 * UsageBillingFeature.kt: the one switch for every usage billing purchase path in the app.
 *
 * Held for this release. Usage billing runs through Stripe, and Google Play's and the App Store's
 * rules on payment outside their own billing differ outside the US, so the app names no purchase
 * path until that's settled. The monthly AI credits themselves are part of each Play plan and
 * always show. While [ENABLED] is false:
 * - activity/AiCreditsActivity.kt shows the credit meter and forecast, but no Set up, Update card
 *   or Turn off button, and a reader who turned usage billing on elsewhere sees it on, with this month's
 *   charges and the monthly limit as read-only text and invoices without links,
 * - the trainer's AI filter card (fragment/AiClassifierSections.kt) shows every credit state's
 *   statement, with no action that leads to Stripe and no cost of usage billing,
 * - AiCreditsActivity.kt never starts a Stripe session, from a button, the trainer or its
 *   <socialCallbackScheme>://usage-billing deep link.
 *
 * The Stripe code and its tests stay in place, so setting [ENABLED] back to true restores all of it.
 * The functions below take the switch as a parameter so tests cover both states.
 */
object UsageBillingFeature {
    const val ENABLED = false

    /** The usage billing button on the AI credits screen, or NONE for no button. */
    @JvmStatic
    fun action(
        credits: AiCredits?,
        enabled: Boolean = ENABLED,
    ): UsageBillingAction = if (enabled) UsageBilling.action(credits) else UsageBillingAction.NONE

    /** Whether AiCreditsActivity.kt may open Stripe Checkout or the billing portal. */
    @JvmStatic
    fun startsStripe(enabled: Boolean = ENABLED): Boolean = enabled

    /** Whether the monthly limit is a field the reader can save, rather than read-only text. */
    @JvmStatic
    fun editsLimit(
        credits: AiCredits?,
        enabled: Boolean = ENABLED,
    ): Boolean = action(credits, enabled) == UsageBillingAction.MANAGE

    /** Whether the AI credits screen offers to turn usage billing off. */
    @JvmStatic
    fun cancels(
        credits: AiCredits?,
        enabled: Boolean = ENABLED,
    ): Boolean = action(credits, enabled) == UsageBillingAction.MANAGE

    /** Whether a usage billing invoice links to Stripe's hosted invoice page, where it can be paid. */
    @JvmStatic
    fun linksInvoices(enabled: Boolean = ENABLED): Boolean = enabled

    /**
     * Whether the AI credits screen has a usage billing section: to offer it while purchases are
     * on, and to show a reader who already has it what it's charging either way.
     */
    @JvmStatic
    fun showsBillingSection(
        credits: AiCredits?,
        enabled: Boolean = ENABLED,
    ): Boolean = credits != null && !credits.isUnlimited && (credits.isUsageBilling || action(credits, enabled) != UsageBillingAction.NONE)
}
