package com.newsblur.network.domain

import com.google.gson.annotations.SerializedName

// AiClassifierResponses.kt: response bodies for the AI prompt classifier and AI credit endpoints in
// apps/analyzer/views.py and apps/profile/views.py.

/** POST /classifier/test_prompt. image_results has one 1 (match) or 0 entry per story image. */
data class PromptTestResponse(
    @SerializedName("code")
    val code: Int = -1,
    @SerializedName("message")
    val message: String? = null,
    @SerializedName("classification")
    val classification: Int = 0,
    @SerializedName("image_results")
    val imageResults: List<Int>? = null,
) {
    val isSuccess: Boolean
        get() = code == 0

    val matched: Boolean
        get() = classification != 0

    fun imageMatched(index: Int): Boolean = imageResults?.getOrNull(index) == 1

    val imageMatchCount: Int
        get() = imageResults?.count { it == 1 } ?: 0
}

/** ai_credits.forecast: this month at the last week's pace, null until there's usage this week. */
data class AiCreditsForecast(
    @SerializedName("credits")
    val credits: Double = 0.0,
    @SerializedName("credits_per_day")
    val creditsPerDay: Double = 0.0,
    // YYYY-MM-DD when the credits run out at this pace, if that's before the month ends.
    @SerializedName("runs_out_on")
    val runsOutOn: String? = null,
    // What the month would cost with usage billing, before any monthly limit.
    @SerializedName("overage_usd")
    val overageUsd: Double = 0.0,
)

/**
 * This month's AI credits, from apps/analyzer/ai_credits.py state(). It comes with user_profile in
 * /reader/feeds and with every AI credit endpoint below. A credit is one US cent of what AI
 * filters cost to run.
 */
data class AiCredits(
    // Credits the plan includes each month: 0 free, 5 Premium, 50 Archive, 500 Pro.
    @SerializedName("included")
    val included: Int = 0,
    @SerializedName("used")
    val used: Double = 0.0,
    @SerializedName("remaining")
    val remaining: Double = 0.0,
    @SerializedName("month")
    val month: String? = null,
    // YYYY-MM-DD, the 1st of next month.
    @SerializedName("resets_on")
    val resetsOn: String? = null,
    // A self-hosted server counts no credits, and the app shows nothing about them.
    @SerializedName("is_unlimited")
    val isUnlimited: Boolean = false,
    @SerializedName("is_billing_available")
    val isBillingAvailable: Boolean = false,
    @SerializedName("is_usage_billing")
    val isUsageBilling: Boolean = false,
    // USD cap on what usage billing charges past the included credits, or null for none.
    @SerializedName("monthly_limit")
    val monthlyLimit: Double? = null,
    @SerializedName("overage_credits")
    val overageCredits: Long = 0,
    @SerializedName("overage_usd")
    val overageUsd: Double = 0.0,
    // Overage not charged yet. NewsBlur charges it at the start of a month once it's at least
    // minimum_charge_usd, or right away once it reaches immediate_charge_usd.
    @SerializedName("unbilled_usd")
    val unbilledUsd: Double = 0.0,
    @SerializedName("minimum_charge_usd")
    val minimumChargeUsd: Double = 1.0,
    @SerializedName("immediate_charge_usd")
    val immediateChargeUsd: Double = 10.0,
    @SerializedName("is_paused")
    val isPaused: Boolean = false,
    // null while filters run, "plan" on a free account, "credits" once they're used, "limit" at the monthly limit.
    @SerializedName("pause_reason")
    val pauseReason: String? = null,
    // 80% of the credits are used, or 80% of the monthly limit.
    @SerializedName("is_warning")
    val isWarning: Boolean = false,
    @SerializedName("credit_usd")
    val creditUsd: Double = 0.01,
    @SerializedName("forecast")
    val forecast: AiCreditsForecast? = null,
)

/**
 * GET /analyzer/ai_classifier_usage?feed_id=N. The two estimates are what a text or an image filter
 * on that site spends a month, from the stories it published last month.
 */
data class AiClassifierUsageResponse(
    @SerializedName("code")
    val code: Int = -1,
    @SerializedName("can_use_ai")
    val canUseAi: Boolean = false,
    @SerializedName("ai_credits")
    val aiCredits: AiCredits? = null,
    @SerializedName("stories_per_month")
    val storiesPerMonth: Int = 0,
    @SerializedName("text_credits_per_month")
    val textCreditsPerMonth: Double = 0.0,
    @SerializedName("image_credits_per_month")
    val imageCreditsPerMonth: Double = 0.0,
) {
    val isSuccess: Boolean
        get() = code == 0
}

data class UsageLineItem(
    @SerializedName("description")
    val description: String? = null,
    // How many AI credits the line bills.
    @SerializedName("quantity")
    val quantity: Long = 0,
    @SerializedName("amount")
    val amount: Double = 0.0,
)

data class UsageInvoice(
    // AiClassifierResponses.kt: dates arrive as YYYY-MM-DD.
    @SerializedName("date")
    val date: String? = null,
    @SerializedName("amount")
    val amount: Double = 0.0,
    @SerializedName("amount_paid")
    val amountPaid: Double = 0.0,
    @SerializedName("status")
    val status: String? = null,
    @SerializedName("hosted_invoice_url")
    val hostedInvoiceUrl: String? = null,
    @SerializedName("invoice_number")
    val invoiceNumber: String? = null,
    @SerializedName("line_items")
    val lineItems: List<UsageLineItem>? = null,
)

/**
 * GET /profile/usage_billing_history: this month's credits and the usage billing invoices. The
 * server charges overage itself now, so upcoming_invoice is null and ai_credits.unbilled_usd
 * says what's waiting.
 */
data class UsageBillingHistoryResponse(
    @SerializedName("code")
    val code: Int = -1,
    @SerializedName("ai_credits")
    val aiCredits: AiCredits? = null,
    @SerializedName("invoices")
    val invoices: List<UsageInvoice>? = null,
    @SerializedName("upcoming_invoice")
    val upcomingInvoice: UsageInvoice? = null,
)

/** POST /profile/cancel_usage_billing turns usage billing off and answers code 0 with the credits. */
data class UsageBillingCancelResponse(
    @SerializedName("code")
    val code: Int = -1,
    @SerializedName("message")
    val message: String? = null,
    @SerializedName("ai_credits")
    val aiCredits: AiCredits? = null,
) {
    val isSuccess: Boolean
        get() = code == 0
}

/** POST /profile/save_usage_billing_limit answers code 1 on success and -1 with a message. */
data class UsageBillingLimitResponse(
    @SerializedName("code")
    val code: Int = -1,
    @SerializedName("limit")
    val limit: Double? = null,
    @SerializedName("message")
    val message: String? = null,
    @SerializedName("ai_credits")
    val aiCredits: AiCredits? = null,
) {
    val isSaved: Boolean
        get() = code == 1
}

/**
 * POST /profile/setup_usage_billing/ and /profile/manage_usage_billing/ with a platform: either a
 * Stripe url to open, already_active when billing is already set up, or code -1 with a message.
 */
data class UsageBillingSessionResponse(
    @SerializedName("code")
    val code: Int = -1,
    @SerializedName("url")
    val url: String? = null,
    @SerializedName("already_active")
    val alreadyActive: Boolean = false,
    @SerializedName("message")
    val message: String? = null,
) {
    val stripeUrl: String?
        get() = url?.takeIf { code == 0 && it.startsWith("https://") }
}
