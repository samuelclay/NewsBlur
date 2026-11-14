package com.newsblur.util

import android.net.Uri
import com.newsblur.BuildConfig
import kotlinx.coroutines.delay
import java.math.BigDecimal
import java.math.RoundingMode
import java.text.DecimalFormatSymbols
import java.util.Locale

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
    /**
     * apps/profile/models.py can_use_ai_classifiers is usage billing or self-hosted AI, so an
     * account that can use AI without self-hosting has billing set up, even when the server or a
     * stale sync hasn't sent is_usage_billing.
     */
    val hasUsageBilling: Boolean
        get() = isUsageBilling || (canUseAiClassifiers && !isSelfHostedAi)

    /** The action the billing buttons offer, following media/js/newsblur/reader/reader_account.js. */
    val action: UsageBillingAction
        get() =
            when {
                hasUsageBilling -> UsageBillingAction.MANAGE
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

    // UsageBilling.kt: billing turns on when Stripe's checkout.session.completed webhook reaches
    // the server, which can land a few seconds after the browser returns setup_complete.
    @JvmField
    val ACTIVATION_BACKOFF_MS = longArrayOf(1_000, 2_000, 4_000)

    /**
     * Checks [isActive] right away and again after each backoff delay, returning true as soon as
     * billing is on and false once the delays run out.
     */
    suspend fun awaitActivation(
        delaysMs: LongArray = ACTIVATION_BACKOFF_MS,
        isActive: suspend () -> Boolean,
    ): Boolean {
        if (isActive()) return true
        for (wait in delaysMs) {
            delay(wait)
            if (isActive()) return true
        }
        return false
    }

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

    private val LIMIT_PATTERN = Regex("""(\d*)(?:[.,](\d{0,2}))?""")

    /**
     * The spending limit field's text the way apps/profile/views.py save_usage_billing_limit
     * parses it with Python's Decimal: "10.50", or "" to clear the limit. A comma-decimal locale
     * types "10,50", so either separator works, with at most two digits after it. Text with both
     * drops the [locale]'s grouping separator, as in German "1.000,50". Null means it isn't an
     * amount, and nothing should be sent.
     */
    @JvmStatic
    fun normalizeLimit(
        input: String,
        locale: Locale,
    ): String? {
        // isWhitespace covers the no-break spaces French and others group thousands with.
        var text = input.filterNot { it.isWhitespace() }
        if (text.isEmpty()) return ""
        if ('.' in text && ',' in text) {
            val grouping = DecimalFormatSymbols.getInstance(locale).groupingSeparator
            if (grouping != '.' && grouping != ',') return null
            text = text.replace(grouping.toString(), "")
        }
        val match = LIMIT_PATTERN.matchEntire(text) ?: return null
        val (whole, fraction) = match.destructured
        if (whole.isEmpty() && fraction.isEmpty()) return null
        return BigDecimal("${whole.ifEmpty { "0" }}.${fraction.ifEmpty { "0" }}").setScale(2).toPlainString()
    }

    /**
     * A saved limit for the spending limit field, like "25" or "10,50" in German. It keeps ASCII
     * digits and no grouping so [normalizeLimit] reads it back, and falls back to "." for a
     * locale whose separator the field can't type.
     */
    @JvmStatic
    fun formatLimit(
        limit: Double?,
        locale: Locale,
    ): String {
        if (limit == null) return ""
        val amount = BigDecimal.valueOf(limit).setScale(2, RoundingMode.HALF_UP)
        if (amount.stripTrailingZeros().scale() <= 0) return amount.toBigInteger().toString()
        val separator = if (DecimalFormatSymbols.getInstance(locale).decimalSeparator == ',') ',' else '.'
        return amount.toPlainString().replace('.', separator)
    }
}
