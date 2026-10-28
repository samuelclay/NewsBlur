package com.newsblur.util

import android.net.Uri
import com.newsblur.BuildConfig

/**
 * Natural language classifier billing flags from /reader/feeds user_profile
 * (apps/profile/models.py), the same values the web reads from NEWSBLUR.Globals.
 */
data class UsageBillingState(
    val isUsageBilling: Boolean = false,
    // UsageBilling.kt: a self-hosted server pays for AI with its own API keys, so there is no billing.
    val isSelfHostedAi: Boolean = false,
    val canUseAiClassifiers: Boolean = false,
    val usageBillingLimit: Double? = null,
) {
    /** The action the billing buttons offer, following media/js/newsblur/reader/reader_account.js. */
    val action: UsageBillingAction
        get() =
            when {
                isUsageBilling -> UsageBillingAction.MANAGE
                isSelfHostedAi -> UsageBillingAction.NONE
                else -> UsageBillingAction.SET_UP
            }
}

enum class UsageBillingAction {
    SET_UP,
    MANAGE,
    NONE,
}

/** Where Stripe sends the Custom Tab back to: <socialCallbackScheme>://usage-billing?status=... */
enum class UsageBillingReturn(
    val status: String,
) {
    SETUP_COMPLETE("setup_complete"),
    CANCELLED("cancelled"),
    PORTAL_RETURN("portal_return"),
}

object UsageBilling {
    const val CALLBACK_HOST = "usage-billing"

    // UsageBilling.kt mirrors onboarding/AccountViewModel.kt: the alpha build has its own
    // callback scheme (app/build.gradle.kts socialCallbackScheme), registered on the server
    // in apps/api/social_auth.py APP_SCHEMES.
    @JvmStatic
    fun platform(applicationId: String = BuildConfig.APPLICATION_ID): String =
        if (applicationId.endsWith(".alpha")) "android-alpha" else "android"

    @JvmStatic
    fun callbackScheme(applicationId: String = BuildConfig.APPLICATION_ID): String =
        if (applicationId.endsWith(".alpha")) "newsblur-auth-android-alpha" else "newsblur-auth-android"

    /** The return from Stripe, or null for any other link. */
    @JvmStatic
    fun parseReturn(
        scheme: String?,
        host: String?,
        status: String?,
        applicationId: String = BuildConfig.APPLICATION_ID,
    ): UsageBillingReturn? {
        if (scheme != callbackScheme(applicationId) || host != CALLBACK_HOST) return null
        return UsageBillingReturn.entries.firstOrNull { it.status == status }
    }

    @JvmStatic
    fun parseReturn(uri: Uri?): UsageBillingReturn? =
        uri?.let { parseReturn(it.scheme, it.host, it.getQueryParameter("status")) }

    /**
     * Formats an amount like media/js/newsblur/reader/reader_classifier.js _format_cost, with
     * more decimals for fractions of a cent.
     */
    @JvmStatic
    fun formatCost(amount: Double): String =
        when {
            amount == 0.0 -> "$0.00"
            amount < 0.005 -> "$" + String.format(java.util.Locale.US, "%.4f", amount)
            amount < 0.10 -> "$" + String.format(java.util.Locale.US, "%.3f", amount)
            else -> formatDollars(amount)
        }

    @JvmStatic
    fun formatDollars(amount: Double): String = "$" + String.format(java.util.Locale.US, "%.2f", amount)
}
