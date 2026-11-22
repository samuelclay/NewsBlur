package com.newsblur.network

import com.newsblur.network.domain.UsageBillingCancelResponse
import com.newsblur.network.domain.UsageBillingHistoryResponse
import com.newsblur.network.domain.UsageBillingLimitResponse
import com.newsblur.network.domain.UsageBillingSessionResponse

/** Usage billing for AI credits past the plan's, used by activity/AiCreditsActivity.kt. */
interface UsageBillingApi {
    /** This month's credits and the usage billing invoices, or null when the request failed. */
    suspend fun getHistory(): UsageBillingHistoryResponse?

    /** A blank limit clears it. */
    suspend fun saveLimit(limit: String): UsageBillingLimitResponse

    /** Turns usage billing off, charging any overage that already comes to the minimum charge. */
    suspend fun cancel(): UsageBillingCancelResponse

    /** Starts Stripe Checkout to save a card, or reports that billing is already active. */
    suspend fun startSetup(platform: String): UsageBillingSessionResponse

    /** Opens the Stripe billing portal, to update the card and see invoices. */
    suspend fun openPortal(platform: String): UsageBillingSessionResponse
}
