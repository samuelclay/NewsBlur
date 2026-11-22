package com.newsblur.util

import android.content.Context
import android.text.format.DateFormat
import com.newsblur.R
import com.newsblur.network.domain.AiCredits
import java.text.ParseException
import java.text.SimpleDateFormat
import java.util.Locale

/** The colors a notice takes from design/AiClassifierPalette.kt. */
enum class AiCreditsNoticeStyle {
    UPGRADE,
    WARNING,
    PAUSED,
    BILLING,
}

/** One credit state's notice: its statement, an optional detail and button, and a closing line. */
data class AiCreditsNotice(
    val style: AiCreditsNoticeStyle,
    val message: String,
    val detail: String? = null,
    val action: AiCreditsAction? = null,
    val actionLabel: String? = null,
    val secondary: String? = null,
)

/**
 * AiCreditsText.kt: the AI credits wording from strings.xml, filled in with the reader's numbers,
 * dollars and dates in the app's language, for fragment/AiClassifierSections.kt,
 * activity/AiCreditsActivity.kt and the Premium screen. Which state applies comes from
 * AiCreditsStatus.kt.
 */
class AiCreditsText(
    private val context: Context,
) {
    private val resources = context.resources

    // The app's language, which the in-app language preference can set apart from the device's.
    val locale: Locale
        get() = resources.configuration.locales[0]

    fun credits(value: Double): String = AiCreditsStatus.formatCredits(value, locale)

    fun planCredits(value: Int): String = AiCreditsStatus.formatPlanCredits(value, locale)

    fun dollars(amount: Double): String = UsageBilling.formatDollars(amount, locale)

    /** A YYYY-MM-DD date as a short month and day, such as Dec 1. */
    fun shortDate(iso: String?): String = formatDate(iso, "MMMd")

    fun formatDate(
        iso: String?,
        skeleton: String,
    ): String {
        val date =
            try {
                iso?.let { SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(it) }
            } catch (_: ParseException) {
                null
            } ?: return ""
        return SimpleDateFormat(DateFormat.getBestDateTimePattern(locale, skeleton), locale).format(date)
    }

    /** "12.3 of 50 AI credits used", or "87.4 AI credits used, 37.4 past your plan's 50". */
    fun meter(credits: AiCredits): String =
        if (AiCreditsStatus.isPastPlan(credits)) {
            resources.getQuantityString(
                R.plurals.ai_credits_meter_past,
                credits.included,
                credits(credits.used),
                credits(AiCreditsStatus.pastPlanCredits(credits)),
                planCredits(credits.included),
            )
        } else {
            resources.getQuantityString(R.plurals.ai_credits_meter, credits.included, credits(credits.used), planCredits(credits.included))
        }

    /** "Resets Dec 1". */
    fun resets(credits: AiCredits): String = context.getString(R.string.ai_credits_resets, shortDate(credits.resetsOn))

    fun free(): String =
        context.getString(
            R.string.ai_credits_free,
            planCredits(AiCreditsStatus.PREMIUM_CREDITS),
            planCredits(AiCreditsStatus.ARCHIVE_CREDITS),
            planCredits(AiCreditsStatus.PRO_CREDITS),
        )

    /** What a text or image filter on this site spends a month, or null without stories to estimate from. */
    fun estimate(
        creditsPerMonth: Double,
        imagePrompt: Boolean,
    ): String? {
        val amount = AiCreditsStatus.formatEstimate(creditsPerMonth, locale) ?: return null
        val small = creditsPerMonth < AiCreditsStatus.SMALLEST_ESTIMATE
        val res =
            when {
                imagePrompt && small -> R.string.ai_credits_estimate_image_small
                imagePrompt -> R.string.ai_credits_estimate_image
                small -> R.string.ai_credits_estimate_text_small
                else -> R.string.ai_credits_estimate_text
            }
        return context.getString(res, amount)
    }

    /** "At this pace your credits run out around Nov 27." while that's still ahead. */
    fun runsOut(credits: AiCredits): String? =
        AiCreditsStatus.runsOutOn(credits)?.let { context.getString(R.string.ai_credits_runs_out, shortDate(it)) }

    /** The month at this pace on the AI credits screen, when it doesn't run out first. */
    fun forecastMonth(credits: AiCredits): String? {
        runsOut(credits)?.let { return it }
        val forecast = credits.forecast ?: return null
        if (!AiCreditsStatus.isRunning(credits) || credits.included <= 0 || credits.isUsageBilling) return null
        return resources.getQuantityString(
            R.plurals.ai_credits_forecast_month,
            credits.included,
            credits(forecast.credits),
            planCredits(credits.included),
        )
    }

    fun planSummary(credits: AiCredits): String =
        resources.getQuantityString(R.plurals.ai_credits_plan_summary, credits.included, planCredits(credits.included))

    fun billingOn(credits: AiCredits): String =
        if (credits.included > 0) {
            resources.getQuantityString(
                R.plurals.ai_credits_billing_on,
                credits.included,
                planCredits(credits.included),
                dollars(credits.overageUsd),
            )
        } else {
            context.getString(R.string.ai_credits_billing_on_no_plan, dollars(credits.overageUsd))
        }

    /** "$0.37 is waiting to be charged: ...", while usage billing has overage it hasn't charged yet. */
    fun unbilled(credits: AiCredits): String? =
        if (credits.isUsageBilling && credits.unbilledUsd > 0) {
            context.getString(
                R.string.ai_credits_unbilled,
                dollars(credits.unbilledUsd),
                dollars(credits.minimumChargeUsd),
                dollars(credits.immediateChargeUsd),
            )
        } else {
            null
        }

    fun limit(credits: AiCredits): String =
        credits.monthlyLimit?.let { context.getString(R.string.usage_billing_limit_read_only, dollars(it)) }
            ?: context.getString(R.string.usage_billing_no_limit)

    /** "About $0.62 this month at your pace.", or null when usage billing wouldn't cost anything yet. */
    fun billingForecast(credits: AiCredits): String? =
        AiCreditsStatus.billingForecastUsd(credits)?.let { context.getString(R.string.ai_credits_billing_forecast, dollars(it)) }

    /**
     * The notice for this month's state, or null when there's nothing to say beyond the meter.
     * [billingEnabled] is util/UsageBillingFeature.kt's switch: with it off no notice offers or
     * prices usage billing. [withActions] false leaves out the buttons, for the AI credits screen,
     * whose usage billing section has its own.
     */
    fun notice(
        credits: AiCredits,
        billingEnabled: Boolean = UsageBillingFeature.ENABLED,
        withActions: Boolean = true,
    ): AiCreditsNotice? {
        val action = if (withActions) AiCreditsStatus.trainerAction(credits, billingEnabled) else null
        val resetsOn = shortDate(credits.resetsOn)
        return when (AiCreditsStatus.stage(credits)) {
            AiCreditsStage.HIDDEN, AiCreditsStage.RUNNING -> null
            AiCreditsStage.FREE ->
                AiCreditsNotice(
                    AiCreditsNoticeStyle.UPGRADE,
                    free(),
                    action = action,
                    actionLabel = context.getString(R.string.ai_credits_upgrade).takeIf { action != null },
                )
            AiCreditsStage.WARNING -> {
                val runsOut = runsOut(credits)
                if (action == null) return runsOut?.let { AiCreditsNotice(AiCreditsNoticeStyle.WARNING, it) }
                val pitch =
                    listOfNotNull(
                        context.getString(R.string.ai_credits_billing_explainer),
                        billingForecast(credits),
                    ).joinToString(" ")
                AiCreditsNotice(
                    AiCreditsNoticeStyle.WARNING,
                    message = runsOut ?: pitch,
                    detail = pitch.takeIf { runsOut != null },
                    action = action,
                    actionLabel = context.getString(R.string.ai_credits_keep_running),
                )
            }
            AiCreditsStage.PAUSED_CREDITS -> {
                val message =
                    resources.getQuantityString(
                        R.plurals.ai_credits_paused,
                        credits.included,
                        resetsOn,
                        planCredits(credits.included),
                    )
                if (action == null) return AiCreditsNotice(AiCreditsNoticeStyle.PAUSED, message)
                val forecast = AiCreditsStatus.billingForecastUsd(credits)
                AiCreditsNotice(
                    AiCreditsNoticeStyle.PAUSED,
                    message = message,
                    detail =
                        if (forecast != null) {
                            context.getString(R.string.ai_credits_turn_on_detail, dollars(forecast))
                        } else {
                            context.getString(R.string.ai_credits_turn_on_detail_no_forecast)
                        },
                    action = action,
                    actionLabel = context.getString(R.string.ai_credits_turn_on_billing),
                    secondary = context.getString(R.string.ai_credits_or_wait, resetsOn),
                )
            }
            AiCreditsStage.USAGE_BILLING ->
                AiCreditsNotice(
                    AiCreditsNoticeStyle.BILLING,
                    message = billingOn(credits),
                    detail = listOfNotNull(unbilled(credits), limit(credits)).joinToString("\n"),
                    action = action,
                    actionLabel = context.getString(R.string.ai_credits_manage_billing).takeIf { action != null },
                )
            AiCreditsStage.PAUSED_LIMIT ->
                AiCreditsNotice(
                    AiCreditsNoticeStyle.PAUSED,
                    message = context.getString(R.string.ai_credits_paused_limit, dollars(credits.monthlyLimit ?: 0.0), resetsOn),
                    action = action,
                    actionLabel = context.getString(R.string.ai_credits_change_limit).takeIf { action != null },
                )
        }
    }
}
