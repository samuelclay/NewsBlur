package com.newsblur.activity

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.newsblur.R
import com.newsblur.databinding.ActivityAiCreditsBinding
import com.newsblur.design.AiClassifierPalette
import com.newsblur.network.ClassifierApi
import com.newsblur.network.UsageBillingApi
import com.newsblur.network.domain.AiCredits
import com.newsblur.network.domain.UsageBillingHistoryResponse
import com.newsblur.network.domain.UsageBillingSessionResponse
import com.newsblur.network.domain.UsageInvoice
import com.newsblur.service.NbSyncManager.UPDATE_METADATA
import com.newsblur.util.AiCreditsAction
import com.newsblur.util.AiCreditsMeterLevel
import com.newsblur.util.AiCreditsStage
import com.newsblur.util.AiCreditsStatus
import com.newsblur.util.AiCreditsText
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.UIUtils
import com.newsblur.util.UsageBilling
import com.newsblur.util.UsageBillingAction
import com.newsblur.util.UsageBillingFeature
import com.newsblur.util.UsageBillingReturn
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject
import kotlin.math.roundToInt

/**
 * This month's AI credits, like the AI credits section of media/js/newsblur/reader/reader_account.js:
 * the meter, the month at the reader's pace, any pause, then usage billing past the credits and its
 * invoices. Setting up and managing usage billing open Stripe in a Custom Tab, which returns here
 * through <socialCallbackScheme>://usage-billing?status=... (apps/profile/views.py
 * usage_billing_app_return). util/UsageBillingFeature.kt holds every Stripe path for this release.
 *
 * The trainer (fragment/AiClassifierSections.kt) opens this screen with an [AiCreditsAction] to go
 * straight on to Stripe Checkout, the billing portal or the monthly limit.
 */
@AndroidEntryPoint
class AiCreditsActivity : NbActivity() {
    @Inject
    lateinit var usageBillingApi: UsageBillingApi

    @Inject
    lateinit var classifierApi: ClassifierApi

    private lateinit var binding: ActivityAiCreditsBinding
    private lateinit var colors: AiClassifierPalette.Colors
    private lateinit var text: AiCreditsText
    private var credits: AiCredits? = null
    private var history: UsageBillingHistoryResponse? = null
    private var loadFailed = false
    private var loadJob: Job? = null
    private var sessionStarting = false

    // The trainer's action, carried out once the first load has the current credits.
    private var pendingAction: AiCreditsAction? = null

    // AiCreditsActivity.kt waits for usage billing to turn on after Stripe Checkout returns, since
    // the server only enables it once Stripe's webhook arrives.
    private var activation = Activation.NONE

    private enum class Activation {
        NONE,
        ACTIVATING,

        // The backoff ran out before the webhook landed. Pull to refresh checks again.
        DELAYED,
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityAiCreditsBinding.inflate(layoutInflater)
        applyView(binding)
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.ai_credits_title), true)
        colors = AiClassifierPalette.colors(prefsRepo.getResolvedTheme(this))
        text = AiCreditsText(this)
        credits = prefsRepo.getAiCredits()
        styleViews()

        binding.refresh.setOnRefreshListener { load() }
        binding.creditsUpgrade.setOnClickListener { UIUtils.startSubscriptionActivity(this) }
        binding.billingButton.setOnClickListener {
            when (UsageBillingFeature.action(credits)) {
                UsageBillingAction.SET_UP -> startStripeSession(setup = true)
                UsageBillingAction.MANAGE -> startStripeSession(setup = false)
                UsageBillingAction.NONE -> Unit
            }
        }
        binding.billingCancel.setOnClickListener { confirmCancel() }
        binding.limitSave.setOnClickListener { saveLimit() }
        binding.limitInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId != EditorInfo.IME_ACTION_DONE) return@setOnEditorActionListener false
            saveLimit()
            true
        }
        if (savedInstanceState == null) {
            handleIntent(intent)
        } else {
            activation = Activation.valueOf(savedInstanceState.getString(STATE_ACTIVATION, Activation.NONE.name))
        }
        render()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putString(STATE_ACTIVATION, activation.name)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        prefsRepo.getAiCredits()?.let { credits = it }
        render()
        load()
    }

    override fun handleUpdate(updateType: Int) {
        // A /reader/feeds refresh brings ai_credits with user_profile.
        if (updateType and UPDATE_METADATA == 0) return
        val updated = prefsRepo.getAiCredits() ?: return
        if (updated == credits) return
        credits = updated
        render()
    }

    private fun handleIntent(intent: Intent?) {
        val result = UsageBilling.parseReturn(intent?.data)
        if (result == null) {
            pendingAction = intent?.getStringExtra(EXTRA_ACTION)?.let { name -> AiCreditsAction.entries.firstOrNull { it.name == name } }
            return
        }
        // UsageBillingFeature.kt: with billing held, a return link only shows the credits.
        if (!UsageBillingFeature.startsStripe()) return
        if (result == UsageBillingReturn.SETUP_COMPLETE && credits?.isUsageBilling != true) activation = Activation.ACTIVATING
        refreshAccountFlags()
        render()
    }

    private fun refreshAccountFlags() {
        syncServiceState.forceFeedsFolders()
        triggerSync()
    }

    private fun load() {
        loadJob?.cancel()
        binding.refresh.isRefreshing = true
        loadJob =
            lifecycleScope.launch {
                if (activation != Activation.NONE) awaitActivation()
                val response = withContext(Dispatchers.IO) { usageBillingApi.getHistory() }
                loadFailed = response == null
                if (response != null) {
                    history = response
                    response.aiCredits?.let(::updateCredits)
                }
                render()
                binding.refresh.isRefreshing = false
                runPendingAction()
            }
    }

    private fun updateCredits(updated: AiCredits) {
        credits = updated
        prefsRepo.setAiCredits(updated)
    }

    private fun runPendingAction() {
        val action = pendingAction ?: return
        pendingAction = null
        when (action) {
            AiCreditsAction.SET_UP_BILLING ->
                if (UsageBillingFeature.action(credits) == UsageBillingAction.SET_UP) startStripeSession(setup = true)
            AiCreditsAction.MANAGE_BILLING -> binding.container.post { binding.container.smoothScrollTo(0, binding.billingCard.top) }
            AiCreditsAction.CHANGE_LIMIT -> if (binding.limitSection.isVisible) focusLimit()
            AiCreditsAction.UPGRADE -> UIUtils.startSubscriptionActivity(this)
        }
    }

    private fun focusLimit() {
        binding.container.post {
            binding.container.smoothScrollTo(0, binding.billingCard.top)
            binding.limitInput.requestFocus()
            getSystemService(InputMethodManager::class.java)?.showSoftInput(binding.limitInput, InputMethodManager.SHOW_IMPLICIT)
        }
    }

    /**
     * Rechecks the account with backoff until the webhook turns usage billing on. The AI usage
     * endpoint is much lighter than /reader/feeds, so it does the polling, and one forced feeds
     * sync then brings the rest of user_profile.
     */
    private suspend fun awaitActivation() {
        render()
        val active =
            UsageBilling.awaitActivation {
                val usage = withContext(Dispatchers.IO) { classifierApi.getAiClassifierUsage(null) }
                val updated = usage.aiCredits?.takeIf { usage.isSuccess }
                updated?.let(::updateCredits)
                updated?.isUsageBilling == true
            }
        if (!active) {
            activation = Activation.DELAYED
            return
        }
        activation = Activation.NONE
        refreshAccountFlags()
        Toast.makeText(this, R.string.usage_billing_setup_complete, Toast.LENGTH_LONG).show()
    }

    private fun startStripeSession(setup: Boolean) {
        if (sessionStarting || !UsageBillingFeature.startsStripe()) return
        sessionStarting = true
        binding.billingButton.isEnabled = false
        lifecycleScope.launch {
            val platform = UsageBilling.platform()
            val response: UsageBillingSessionResponse =
                withContext(Dispatchers.IO) {
                    if (setup) usageBillingApi.startSetup(platform) else usageBillingApi.openPortal(platform)
                }
            sessionStarting = false
            binding.billingButton.isEnabled = true
            val url = response.stripeUrl
            when {
                response.alreadyActive -> {
                    Toast.makeText(this@AiCreditsActivity, R.string.usage_billing_already_active, Toast.LENGTH_LONG).show()
                    refreshAccountFlags()
                    load()
                }
                url != null -> openInCustomTab(Uri.parse(url))
                else -> {
                    val message = response.message ?: getString(R.string.usage_billing_stripe_failed)
                    Toast.makeText(this@AiCreditsActivity, message, Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    private fun openInCustomTab(uri: Uri) {
        try {
            CustomTabsIntent
                .Builder()
                .setShowTitle(true)
                .build()
                .launchUrl(this, uri)
        } catch (_: ActivityNotFoundException) {
            Toast.makeText(this, R.string.usage_billing_no_browser, Toast.LENGTH_LONG).show()
        }
    }

    private fun confirmCancel() {
        if (!UsageBillingFeature.cancels(credits)) return
        val minimum = text.dollars(credits?.minimumChargeUsd ?: 1.0)
        MaterialAlertDialogBuilder(this)
            .setMessage(getString(R.string.usage_billing_cancel_confirm, minimum))
            .setPositiveButton(R.string.usage_billing_cancel) { _, _ -> cancelBilling() }
            .setNegativeButton(R.string.usage_billing_cancel_keep, null)
            .show()
    }

    private fun cancelBilling() {
        binding.billingCancel.isEnabled = false
        lifecycleScope.launch {
            val response = withContext(Dispatchers.IO) { usageBillingApi.cancel() }
            binding.billingCancel.isEnabled = true
            if (!response.isSuccess) {
                val message = response.message ?: getString(R.string.usage_billing_cancel_failed)
                Toast.makeText(this@AiCreditsActivity, message, Toast.LENGTH_LONG).show()
                return@launch
            }
            response.aiCredits?.let(::updateCredits)
            Toast.makeText(this@AiCreditsActivity, R.string.usage_billing_cancelled, Toast.LENGTH_SHORT).show()
            refreshAccountFlags()
            render()
        }
    }

    private fun saveLimit() {
        if (!UsageBillingFeature.editsLimit(credits)) return
        // AiCreditsActivity.kt sends "10.50" whichever decimal separator the locale typed.
        val limit = UsageBilling.normalizeLimit(binding.limitInput.text.toString(), text.locale)
        if (limit == null) {
            Toast.makeText(this, getString(R.string.usage_billing_limit_invalid, formatLimit(10.5)), Toast.LENGTH_LONG).show()
            return
        }
        binding.limitSave.isEnabled = false
        lifecycleScope.launch {
            val response = withContext(Dispatchers.IO) { usageBillingApi.saveLimit(limit) }
            binding.limitSave.isEnabled = true
            if (!response.isSaved) {
                val message = response.message ?: getString(R.string.usage_billing_limit_failed)
                Toast.makeText(this@AiCreditsActivity, message, Toast.LENGTH_LONG).show()
                return@launch
            }
            response.aiCredits?.let(::updateCredits)
            Toast
                .makeText(
                    this@AiCreditsActivity,
                    if (response.limit == null) R.string.usage_billing_limit_cleared else R.string.usage_billing_limit_saved,
                    Toast.LENGTH_SHORT,
                ).show()
            binding.limitInput.clearFocus()
            render()
        }
    }

    private fun render() {
        val credits = credits
        if (credits == null || credits.isUnlimited) {
            listOf(binding.creditsMeter, binding.creditsForecast, binding.creditsNotice, binding.creditsUpgrade, binding.creditsPlan)
                .forEach { it.isVisible = false }
            binding.billingCard.isVisible = false
            binding.historyCard.isVisible = false
            binding.creditsMessage.isVisible = true
            binding.creditsMessage.setText(
                when {
                    credits != null -> R.string.ai_credits_unlimited
                    loadFailed -> R.string.ai_credits_load_failed
                    else -> R.string.loading
                },
            )
            return
        }
        binding.creditsMessage.isVisible = false
        renderCredits(credits)
        renderBilling(credits)
        renderHistory(credits)
    }

    private fun renderCredits(credits: AiCredits) {
        val stage = AiCreditsStatus.stage(credits)
        val showsMeter = AiCreditsStatus.showsMeter(credits)
        binding.creditsMeter.isVisible = showsMeter
        if (showsMeter) {
            binding.creditsUsed.text = text.meter(credits)
            binding.creditsResets.text = text.resets(credits)
            binding.creditsBar.bind(
                AiCreditsStatus.meterFraction(credits),
                colors.meterTrack,
                colors.meterColor(AiCreditsStatus.meterLevel(credits)),
            )
        }

        val forecast = text.forecastMonth(credits)
        binding.creditsForecast.text = forecast
        binding.creditsForecast.isVisible = forecast != null
        binding.creditsForecast.setTextColor(
            if (AiCreditsStatus.meterLevel(credits) == AiCreditsMeterLevel.WARNING) colors.warningText else colors.textPrimary,
        )

        // The pauses and a free account's plans. Low credits read in the forecast above, and
        // usage billing in its own card below, along with every button that leads to Stripe.
        val notice =
            when (stage) {
                AiCreditsStage.FREE, AiCreditsStage.PAUSED_CREDITS, AiCreditsStage.PAUSED_LIMIT -> text.notice(credits, withActions = false)
                else -> null
            }
        binding.creditsNotice.isVisible = notice != null
        if (notice != null) {
            val free = stage == AiCreditsStage.FREE
            binding.creditsNotice.text = notice.message
            binding.creditsNotice.setTextColor(if (free) colors.upgradeText else colors.pausedText)
            binding.creditsNotice.background =
                if (free) {
                    rounded(colors.upgradeBackground, colors.upgradeBorder, radiusDp = 8)
                } else {
                    rounded(colors.pausedBackground, colors.pausedBorder, radiusDp = 8)
                }
        }
        binding.creditsUpgrade.isVisible = stage == AiCreditsStage.FREE

        binding.creditsPlan.isVisible = credits.included > 0
        if (credits.included > 0) binding.creditsPlan.text = text.planSummary(credits)
    }

    private fun renderBilling(credits: AiCredits) {
        binding.billingCard.isVisible = UsageBillingFeature.showsBillingSection(credits)
        if (!binding.billingCard.isVisible) return

        val action = UsageBillingFeature.action(credits)
        val on = credits.isUsageBilling
        binding.billingStatus.text =
            when {
                activation == Activation.ACTIVATING -> getString(R.string.usage_billing_activating)
                activation == Activation.DELAYED -> getString(R.string.usage_billing_activating_slow)
                on -> text.billingOn(credits)
                else -> getString(R.string.ai_credits_billing_explainer)
            }

        // What the month comes to at this pace, the number a reader decides on.
        val forecast = text.billingForecast(credits)?.takeIf { activation == Activation.NONE }
        binding.billingForecast.text = forecast
        binding.billingForecast.isVisible = forecast != null

        val detail =
            if (on) {
                text.unbilled(credits)
            } else {
                getString(R.string.usage_billing_terms, text.dollars(credits.minimumChargeUsd), text.dollars(credits.immediateChargeUsd))
            }
        binding.billingDetail.text = detail
        binding.billingDetail.isVisible = detail != null

        when (action) {
            UsageBillingAction.MANAGE -> binding.billingButton.setText(R.string.usage_billing_manage)
            UsageBillingAction.SET_UP -> binding.billingButton.setText(R.string.usage_billing_set_up)
            UsageBillingAction.NONE -> Unit
        }
        // No second checkout while Stripe is still confirming the first.
        binding.billingButton.isVisible = action != UsageBillingAction.NONE && activation == Activation.NONE
        binding.billingCancel.isVisible = UsageBillingFeature.cancels(credits) && activation == Activation.NONE

        val editsLimit = on && UsageBillingFeature.editsLimit(credits)
        binding.limitSection.isVisible = editsLimit
        if (editsLimit && !binding.limitInput.hasFocus()) binding.limitInput.setText(formatLimit(credits.monthlyLimit))
        // UsageBillingFeature.kt: with billing held, the limit set elsewhere still shows.
        binding.limitReadOnly.isVisible = on && !editsLimit
        if (on && !editsLimit) binding.limitReadOnly.text = text.limit(credits)
    }

    private fun renderHistory(credits: AiCredits) {
        binding.historyCard.isVisible = credits.isUsageBilling
        if (!credits.isUsageBilling) return
        binding.historyList.removeAllViews()
        val history = history
        if (history == null) {
            showHistoryMessage(getString(if (loadFailed) R.string.ai_credits_load_failed else R.string.loading))
            return
        }
        val invoices = history.invoices.orEmpty()
        val upcoming = history.upcomingInvoice
        if (invoices.isEmpty() && upcoming == null) {
            showHistoryMessage(getString(R.string.usage_billing_no_invoices))
            return
        }
        binding.historyMessage.isVisible = false
        upcoming?.let { addInvoiceRow(it, it.amount, getString(R.string.usage_billing_upcoming), scheduled = true) }
        for (invoice in invoices) {
            addInvoiceRow(invoice, invoice.amountPaid, invoice.status.orEmpty(), scheduled = invoice.status == "draft")
        }
    }

    private fun showHistoryMessage(message: String) {
        binding.historyMessage.text = message
        binding.historyMessage.isVisible = true
    }

    private fun addInvoiceRow(
        invoice: UsageInvoice,
        amount: Double,
        status: String,
        scheduled: Boolean,
    ) {
        if (binding.historyList.childCount > 0) {
            binding.historyList.addView(
                View(this).apply {
                    setBackgroundColor(colors.cardBorder)
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(1)).apply { topMargin = dp(10) }
                },
            )
        }
        val header =
            LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                layoutParams = rowParams(topMarginDp = 10)
                alpha = if (scheduled) 0.7f else 1f
            }
        header.addView(textView(text.formatDate(invoice.date, "yMMMd"), colors.textPrimary, 14f), fillParams())
        header.addView(textView(text.dollars(amount), colors.textPrimary, 14f, bold = true))
        if (status.isNotEmpty()) header.addView(textView(status, colors.textSecondary, 13f), trailingParams())
        binding.historyList.addView(header)

        // UsageBillingFeature.kt: Stripe's hosted invoice can take a payment, so it links only while billing is on.
        invoice.hostedInvoiceUrl?.takeIf { it.startsWith("https://") && UsageBillingFeature.linksInvoices() }?.let { url ->
            binding.historyList.addView(
                textView(getString(R.string.usage_billing_invoice), colors.accent, 13f, bold = true).apply {
                    setPadding(0, dp(4), 0, dp(4))
                    setOnClickListener { UIUtils.handleUri(this@AiCreditsActivity, prefsRepo, Uri.parse(url)) }
                },
            )
        }
        for (item in invoice.lineItems.orEmpty()) {
            val row =
                LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    layoutParams = rowParams(topMarginDp = 2)
                }
            val quantity =
                resources.getQuantityString(
                    R.plurals.usage_billing_quantity,
                    item.quantity.coerceAtMost(Int.MAX_VALUE.toLong()).toInt(),
                    java.text.NumberFormat
                        .getIntegerInstance(text.locale)
                        .format(item.quantity),
                )
            row.addView(textView(item.description.orEmpty(), colors.textSecondary, 12f), fillParams())
            row.addView(textView(quantity, colors.textSecondary, 12f))
            row.addView(textView(text.dollars(item.amount), colors.textSecondary, 12f), trailingParams())
            binding.historyList.addView(row)
        }
    }

    private fun rowParams(topMarginDp: Int) =
        LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(topMarginDp)
        }

    private fun fillParams() = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)

    private fun trailingParams() =
        LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            marginStart = dp(8)
        }

    private fun textView(
        value: String,
        color: Int,
        sizeSp: Float,
        bold: Boolean = false,
    ) = TextView(this).apply {
        text = value
        setTextColor(color)
        textSize = sizeSp
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

    private fun styleViews() {
        binding.container.setBackgroundColor(colors.screenBackground)
        binding.refresh.setBackgroundColor(colors.screenBackground)
        listOf(binding.creditsCard, binding.billingCard, binding.historyCard).forEach {
            it.background = rounded(colors.cardBackground, colors.cardBorder, radiusDp = 10)
        }
        listOf(
            binding.creditsUsed,
            binding.creditsMessage,
            binding.billingTitle,
            binding.billingStatus,
            binding.historyTitle,
            binding.limitLabel,
            binding.limitDollar,
            binding.limitReadOnly,
        ).forEach { it.setTextColor(colors.textPrimary) }
        listOf(
            binding.creditsResets,
            binding.creditsPlan,
            binding.billingDetail,
            binding.limitHelp,
            binding.historyMessage,
        ).forEach { it.setTextColor(colors.textSecondary) }
        binding.billingForecast.setTextColor(colors.billingText)
        binding.billingForecast.setTypeface(binding.billingForecast.typeface, Typeface.BOLD)
        binding.billingForecast.background = rounded(colors.billingBackground, colors.billingBorder, radiusDp = 8)
        binding.limitInput.background = rounded(colors.inputBackground, colors.cardBorder, radiusDp = 6)
        binding.limitInput.setTextColor(colors.textPrimary)
        binding.limitInput.setHintTextColor(colors.textSecondary)
        listOf(binding.billingButton, binding.limitSave, binding.creditsUpgrade).forEach {
            it.backgroundTintList = ColorStateList.valueOf(colors.accent)
            it.setTextColor(colors.accentText)
        }
        binding.billingCancel.setTextColor(colors.textPrimary)
        binding.billingCancel.strokeColor = ColorStateList.valueOf(colors.cardBorder)
    }

    private fun rounded(
        fill: Int,
        stroke: Int? = null,
        radiusDp: Int,
    ) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = dp(radiusDp).toFloat()
        setColor(fill)
        if (stroke != null) setStroke(dp(1), stroke)
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).roundToInt()

    private fun formatLimit(limit: Double?): String = UsageBilling.formatLimit(limit, text.locale)

    companion object {
        private const val STATE_ACTIVATION = "ai_credits_activation"
        private const val EXTRA_ACTION = "ai_credits_action"

        /** Opens the AI credits screen, going straight on to [action] once it has loaded. */
        @JvmStatic
        fun intent(
            context: Context,
            action: AiCreditsAction? = null,
        ): Intent = Intent(context, AiCreditsActivity::class.java).apply { action?.let { putExtra(EXTRA_ACTION, it.name) } }
    }
}
