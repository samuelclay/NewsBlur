package com.newsblur.util

import com.newsblur.network.domain.AiCredits
import java.math.BigDecimal
import java.math.RoundingMode
import java.text.NumberFormat
import java.util.Locale

/** Which of the AI credit states in the AI credits spec a reader is in this month. */
enum class AiCreditsStage {
    // No credits to show: a self-hosted server that counts none, or nothing synced yet.
    HIDDEN,

    // A free account: filters save and test, but only run on a paid plan.
    FREE,
    RUNNING,

    // 80% of the month's credits are used and filters will pause when the rest are.
    WARNING,

    // Filters run past the plan's credits, billed at 1 cent per credit.
    USAGE_BILLING,

    // The month's credits are used and filters wait for the 1st.
    PAUSED_CREDITS,

    // Usage billing reached the reader's monthly limit.
    PAUSED_LIMIT,
}

enum class AiCreditsMeterLevel {
    NORMAL,
    WARNING,
    PAUSED,
}

/** Where a credit state's button in the trainer leads. */
enum class AiCreditsAction {
    // The Premium upgrade screen, through Google Play.
    UPGRADE,

    // AiCreditsActivity.kt, straight into Stripe Checkout.
    SET_UP_BILLING,

    // AiCreditsActivity.kt's usage billing section: the card on Stripe, the monthly limit, turning it off.
    MANAGE_BILLING,

    // AiCreditsActivity.kt's monthly limit field.
    CHANGE_LIMIT,
}

/**
 * AiCreditsStatus.kt: reads apps/analyzer/ai_credits.py state() into what the trainer's AI sections
 * (fragment/AiClassifierSections.kt), the AI credits screen (activity/AiCreditsActivity.kt) and the
 * Premium screen show, so every screen agrees on the state and its wording stays in one place.
 */
object AiCreditsStatus {
    const val PAUSE_PLAN = "plan"
    const val PAUSE_CREDITS = "credits"
    const val PAUSE_LIMIT = "limit"

    // The credits each paid plan includes a month (apps/analyzer/ai_credits.py MONTHLY_CREDITS_*),
    // for the plan lists and the free account's explanation, which name every plan's.
    const val PREMIUM_CREDITS = 5
    const val ARCHIVE_CREDITS = 50
    const val PRO_CREDITS = 500

    @JvmStatic
    fun stage(credits: AiCredits?): AiCreditsStage =
        when {
            credits == null || credits.isUnlimited -> AiCreditsStage.HIDDEN
            credits.pauseReason == PAUSE_PLAN -> AiCreditsStage.FREE
            credits.pauseReason == PAUSE_LIMIT -> AiCreditsStage.PAUSED_LIMIT
            // A pause this build doesn't know yet still says the filters are paused.
            credits.pauseReason == PAUSE_CREDITS || credits.isPaused -> AiCreditsStage.PAUSED_CREDITS
            credits.isUsageBilling -> AiCreditsStage.USAGE_BILLING
            credits.isWarning -> AiCreditsStage.WARNING
            else -> AiCreditsStage.RUNNING
        }

    /** Whether the stage has a used-of-included meter: every one but a free account's, when there are credits to count. */
    @JvmStatic
    fun showsMeter(credits: AiCredits?): Boolean {
        val stage = stage(credits)
        return stage != AiCreditsStage.HIDDEN && stage != AiCreditsStage.FREE && (credits?.included ?: 0) > 0
    }

    @JvmStatic
    fun meterLevel(credits: AiCredits): AiCreditsMeterLevel =
        when {
            credits.isPaused -> AiCreditsMeterLevel.PAUSED
            credits.isWarning -> AiCreditsMeterLevel.WARNING
            else -> AiCreditsMeterLevel.NORMAL
        }

    /** How much of the meter is filled, full once the credits are used, even as usage billing goes past them. */
    @JvmStatic
    fun meterFraction(credits: AiCredits): Float {
        if (credits.included <= 0) return if (credits.used > 0) 1f else 0f
        return (credits.used / credits.included).toFloat().coerceIn(0f, 1f)
    }

    // AiCreditsStatus.kt: credits rounded to one decimal place, as formatCredits shows them
    // (DecimalFormat rounds a double's exact value half-even).
    private fun displayed(value: Double): BigDecimal = BigDecimal(value).setScale(1, RoundingMode.HALF_EVEN)

    /**
     * Whether the meter reads as past the plan's credits, comparing the numbers as they show, so
     * 50.04 used of 50 still reads "50 of 50".
     */
    @JvmStatic
    fun isPastPlan(credits: AiCredits): Boolean = credits.included > 0 && displayed(credits.used) > BigDecimal(credits.included)

    /** The credits past the plan's, as the meter shows them, such as 37.4. */
    @JvmStatic
    fun pastPlanCredits(credits: AiCredits): Double =
        if (isPastPlan(credits)) displayed(credits.used).subtract(BigDecimal(credits.included)).toDouble() else 0.0

    /**
     * With usage billing past the plan's credits, the share of the bar the plan's own credits
     * fill, the rest being billed credits. Null for a bar in one color.
     */
    @JvmStatic
    fun planShare(credits: AiCredits): Float? =
        if (credits.isUsageBilling && isPastPlan(credits)) (credits.included / credits.used).toFloat().coerceIn(0f, 1f) else null

    /** Whether filters score stories this month, so a site's estimate is worth showing. */
    @JvmStatic
    fun isRunning(credits: AiCredits?): Boolean =
        when (stage(credits)) {
            AiCreditsStage.RUNNING, AiCreditsStage.WARNING, AiCreditsStage.USAGE_BILLING -> true
            else -> false
        }

    /**
     * The date the credits run out at this pace, while that's still ahead and filters aren't
     * already paused or billed past them.
     */
    @JvmStatic
    fun runsOutOn(credits: AiCredits?): String? =
        when (stage(credits)) {
            AiCreditsStage.RUNNING, AiCreditsStage.WARNING -> credits?.forecast?.runsOutOn
            else -> null
        }

    /** What usage billing would cost this month at the reader's pace, or null when it's nothing. */
    @JvmStatic
    fun billingForecastUsd(credits: AiCredits?): Double? = credits?.forecast?.overageUsd?.takeIf { it > 0 }

    /**
     * The trainer's button for this state. Upgrading goes through Google Play and always shows.
     * Every Stripe action needs [billingEnabled] (util/UsageBillingFeature.kt), so with it off a
     * warning or a pause is a statement with nothing to press.
     */
    @JvmStatic
    fun trainerAction(
        credits: AiCredits?,
        billingEnabled: Boolean = UsageBillingFeature.ENABLED,
    ): AiCreditsAction? {
        val stage = stage(credits)
        if (stage == AiCreditsStage.FREE) return AiCreditsAction.UPGRADE
        if (!billingEnabled || credits == null) return null
        return when (stage) {
            AiCreditsStage.WARNING, AiCreditsStage.PAUSED_CREDITS ->
                if (credits.isBillingAvailable && !credits.isUsageBilling) AiCreditsAction.SET_UP_BILLING else null
            AiCreditsStage.USAGE_BILLING -> AiCreditsAction.MANAGE_BILLING
            AiCreditsStage.PAUSED_LIMIT -> AiCreditsAction.CHANGE_LIMIT
            else -> null
        }
    }

    /** Credits with up to one decimal place in the reader's language, such as 12.3 or 12,3. */
    @JvmStatic
    fun formatCredits(
        value: Double,
        locale: Locale,
    ): String {
        val format = NumberFormat.getNumberInstance(locale)
        format.minimumFractionDigits = 0
        format.maximumFractionDigits = 1
        return format.format(value)
    }

    /** A plan's whole credits, grouped in the reader's language, such as 500. */
    @JvmStatic
    fun formatPlanCredits(
        value: Int,
        locale: Locale,
    ): String = NumberFormat.getIntegerInstance(locale).format(value)

    // AiCreditsStatus.kt: below this a filter's monthly estimate shows as "less than 0.1".
    const val SMALLEST_ESTIMATE = 0.1

    /**
     * A site's monthly estimate with one decimal place, so even a whole number reads as an amount
     * ("1.0 credits"), or null when the site published nothing last month to estimate from.
     */
    @JvmStatic
    fun formatEstimate(
        value: Double,
        locale: Locale,
    ): String? {
        if (value <= 0) return null
        val format = NumberFormat.getNumberInstance(locale)
        format.minimumFractionDigits = if (value < 10) 1 else 0
        format.maximumFractionDigits = 1
        return format.format(maxOf(value, SMALLEST_ESTIMATE))
    }
}
