package com.newsblur.network.domain

import com.google.gson.annotations.SerializedName

// AiClassifierResponses.kt: response bodies for the AI prompt classifier and usage billing
// endpoints in apps/analyzer/views.py and apps/profile/views.py.

/** Average AI cost per story from apps/analyzer/vlm_usage.py AIClassifierCostEstimator. */
data class AiCostEstimate(
    @SerializedName("avg_cost_per_text")
    val avgCostPerText: Double = 0.0,
    @SerializedName("avg_cost_per_image")
    val avgCostPerImage: Double = 0.0,
)

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
    @SerializedName("cost_estimate")
    val costEstimate: AiCostEstimate? = null,
) {
    val isSuccess: Boolean
        get() = code == 0

    val matched: Boolean
        get() = classification != 0

    fun imageMatched(index: Int): Boolean = imageResults?.getOrNull(index) == 1

    val imageMatchCount: Int
        get() = imageResults?.count { it == 1 } ?: 0
}

/** GET /classifier/ai_classifier_usage, which only fills the costs when can_use_ai is true. */
data class AiClassifierUsageResponse(
    @SerializedName("code")
    val code: Int = -1,
    @SerializedName("can_use_ai")
    val canUseAi: Boolean = false,
    @SerializedName("avg_cost_per_text")
    val avgCostPerText: Double = 0.0,
    @SerializedName("avg_cost_per_image")
    val avgCostPerImage: Double = 0.0,
    @SerializedName("current_cycle_spend")
    val currentCycleSpend: Double = 0.0,
    @SerializedName("usage_billing_limit")
    val usageBillingLimit: Double? = null,
    @SerializedName("is_limit_reached")
    val isLimitReached: Boolean = false,
) {
    val costEstimate: AiCostEstimate
        get() = AiCostEstimate(avgCostPerText, avgCostPerImage)
}

data class UsageLineItem(
    @SerializedName("description")
    val description: String? = null,
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

/** GET /profile/usage_billing_history. */
data class UsageBillingHistoryResponse(
    @SerializedName("invoices")
    val invoices: List<UsageInvoice>? = null,
    @SerializedName("upcoming_invoice")
    val upcomingInvoice: UsageInvoice? = null,
    @SerializedName("current_cycle_spend")
    val currentCycleSpend: Double? = null,
    @SerializedName("usage_billing_limit")
    val usageBillingLimit: Double? = null,
    @SerializedName("is_limit_reached")
    val isLimitReached: Boolean = false,
    @SerializedName("is_self_hosted")
    val isSelfHosted: Boolean = false,
    @SerializedName("cycle_start")
    val cycleStart: String? = null,
    @SerializedName("cycle_end")
    val cycleEnd: String? = null,
)

/** POST /profile/save_usage_billing_limit answers code 1 on success and -1 with a message. */
data class UsageBillingLimitResponse(
    @SerializedName("code")
    val code: Int = -1,
    @SerializedName("limit")
    val limit: Double? = null,
    @SerializedName("message")
    val message: String? = null,
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
