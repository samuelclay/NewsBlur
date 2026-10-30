package com.newsblur.network

import com.newsblur.network.domain.UsageBillingHistoryResponse
import com.newsblur.network.domain.UsageBillingLimitResponse
import com.newsblur.network.domain.UsageBillingSessionResponse

/** Usage-based billing for natural language classifiers, used by UsageBillingActivity.kt. */
interface UsageBillingApi {
    /** Null when the request failed. */
    suspend fun getHistory(): UsageBillingHistoryResponse?

    /** A blank limit clears it. */
    suspend fun saveLimit(limit: String): UsageBillingLimitResponse

    /** Starts Stripe Checkout, or reports that billing is already active. */
    suspend fun startSetup(platform: String): UsageBillingSessionResponse

    /** Opens the Stripe billing portal. */
    suspend fun openPortal(platform: String): UsageBillingSessionResponse
}
