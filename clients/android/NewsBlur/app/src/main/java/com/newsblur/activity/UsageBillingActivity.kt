package com.newsblur.activity

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.text.format.DateFormat
import android.view.Gravity
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import com.newsblur.R
import com.newsblur.databinding.ActivityUsageBillingBinding
import com.newsblur.design.AiClassifierPalette
import com.newsblur.network.ClassifierApi
import com.newsblur.network.UsageBillingApi
import com.newsblur.network.domain.UsageBillingHistoryResponse
import com.newsblur.network.domain.UsageBillingSessionResponse
import com.newsblur.network.domain.UsageInvoice
import com.newsblur.service.NbSyncManager.UPDATE_METADATA
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.UIUtils
import com.newsblur.util.UsageBilling
import com.newsblur.util.UsageBillingAction
import com.newsblur.util.UsageBillingReturn
import com.newsblur.util.UsageBillingState
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import javax.inject.Inject
import kotlin.math.roundToInt

/**
 * Natural language classifier billing: the web's "Natural language classifier billing" and "Usage
 * billing history" sections of media/js/newsblur/reader/reader_account.js. Setting up and managing
 * billing open Stripe in a Custom Tab, which returns here through
 * <socialCallbackScheme>://usage-billing?status=... (apps/profile/views.py usage_billing_app_return).
 */
@AndroidEntryPoint
class UsageBillingActivity : NbActivity() {
    @Inject
    lateinit var usageBillingApi: UsageBillingApi

    @Inject
    lateinit var classifierApi: ClassifierApi

    private lateinit var binding: ActivityUsageBillingBinding
    private lateinit var colors: AiClassifierPalette.Colors
    private var billing = UsageBillingState()
    private var loadJob: Job? = null
    private var sessionStarting = false

    // UsageBillingActivity.kt rechecks a few times after Stripe Checkout, since the webhook
    // that turns billing on can land a moment after the browser returns.
    private var confirmSetupAttempts = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityUsageBillingBinding.inflate(layoutInflater)
        applyView(binding)
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.usage_billing_title), true)
        colors = AiClassifierPalette.colors(prefsRepo.getResolvedTheme(this))
        billing = prefsRepo.getUsageBillingState()
        styleViews()

        binding.refresh.setOnRefreshListener { load() }
        binding.billingButton.setOnClickListener {
            when (billing.action) {
                UsageBillingAction.SET_UP -> startStripeSession(setup = true)
                UsageBillingAction.MANAGE -> startStripeSession(setup = false)
                UsageBillingAction.NONE -> Unit
            }
        }
        binding.limitSave.setOnClickListener { saveLimit() }
        binding.limitInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId != EditorInfo.IME_ACTION_DONE) return@setOnEditorActionListener false
            saveLimit()
            true
        }
        if (savedInstanceState == null) handleStripeReturn(intent)
        render()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleStripeReturn(intent)
    }

    override fun onResume() {
        super.onResume()
        billing = prefsRepo.getUsageBillingState()
        render()
        load()
    }

    override fun handleUpdate(updateType: Int) {
        // A /reader/feeds refresh brings is_usage_billing and the other flags from user_profile.
        if (updateType and UPDATE_METADATA == 0) return
        val updated = prefsRepo.getUsageBillingState()
        if (updated == billing) return
        billing = updated
        render()
        load()
    }

    private fun handleStripeReturn(intent: Intent?) {
        val result = UsageBilling.parseReturn(intent?.data) ?: return
        if (result == UsageBillingReturn.SETUP_COMPLETE) {
            Toast.makeText(this, R.string.usage_billing_setup_complete, Toast.LENGTH_LONG).show()
            confirmSetupAttempts = 3
        }
        refreshAccountFlags()
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
                var usage = withContext(Dispatchers.IO) { classifierApi.getAiClassifierUsage(null) }
                while (usage.code == 0 && !usage.canUseAi && confirmSetupAttempts > 0) {
                    confirmSetupAttempts--
                    delay(2_000)
                    usage = withContext(Dispatchers.IO) { classifierApi.getAiClassifierUsage(null) }
                }
                if (usage.code == 0 && usage.canUseAi) confirmSetupAttempts = 0
                if (usage.code == 0 && usage.canUseAi != billing.canUseAiClassifiers) {
                    billing = billing.copy(canUseAiClassifiers = usage.canUseAi)
                    prefsRepo.setUsageBillingState(billing)
                    refreshAccountFlags()
                }
                render()
                if (!billing.canUseAiClassifiers) {
                    renderHistory(null, failed = false)
                } else {
                    val history = withContext(Dispatchers.IO) { usageBillingApi.getHistory() }
                    renderHistory(history, failed = history == null)
                }
                binding.refresh.isRefreshing = false
            }
    }

    private fun startStripeSession(setup: Boolean) {
        if (sessionStarting) return
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
                    Toast.makeText(this@UsageBillingActivity, R.string.usage_billing_already_active, Toast.LENGTH_LONG).show()
                    refreshAccountFlags()
                    load()
                }
                url != null -> openInCustomTab(Uri.parse(url))
                else ->
                    Toast
                        .makeText(this@UsageBillingActivity, response.message ?: getString(R.string.usage_billing_stripe_failed), Toast.LENGTH_LONG)
                        .show()
            }
        }
    }

    private fun openInCustomTab(uri: Uri) {
        try {
            CustomTabsIntent.Builder().setShowTitle(true).build().launchUrl(this, uri)
        } catch (_: ActivityNotFoundException) {
            Toast.makeText(this, R.string.usage_billing_no_browser, Toast.LENGTH_LONG).show()
        }
    }

    private fun saveLimit() {
        val limit = binding.limitInput.text.toString().trim()
        binding.limitSave.isEnabled = false
        lifecycleScope.launch {
            val response = withContext(Dispatchers.IO) { usageBillingApi.saveLimit(limit) }
            binding.limitSave.isEnabled = true
            if (!response.isSaved) {
                Toast.makeText(this@UsageBillingActivity, response.message ?: getString(R.string.usage_billing_limit_failed), Toast.LENGTH_LONG).show()
                return@launch
            }
            billing = billing.copy(usageBillingLimit = response.limit)
            prefsRepo.setUsageBillingState(billing)
            Toast
                .makeText(
                    this@UsageBillingActivity,
                    if (response.limit == null) R.string.usage_billing_limit_cleared else R.string.usage_billing_limit_saved,
                    Toast.LENGTH_SHORT,
                ).show()
            binding.limitInput.clearFocus()
            load()
        }
    }

    private fun render() {
        binding.billingStatus.setText(
            when {
                billing.isUsageBilling -> R.string.usage_billing_status_enabled
                billing.isSelfHostedAi -> R.string.usage_billing_status_self_hosted
                else -> R.string.usage_billing_status_off
            },
        )
        when (billing.action) {
            UsageBillingAction.MANAGE -> binding.billingButton.setText(R.string.usage_billing_manage)
            UsageBillingAction.SET_UP -> binding.billingButton.setText(R.string.ai_billing_set_up)
            UsageBillingAction.NONE -> Unit
        }
        binding.billingButton.isVisible = billing.action != UsageBillingAction.NONE
        binding.limitSection.isVisible = billing.canUseAiClassifiers
        if (!binding.limitInput.hasFocus()) binding.limitInput.setText(formatLimit(billing.usageBillingLimit))
        if (!billing.canUseAiClassifiers) binding.spendSection.isVisible = false
    }

    private fun renderHistory(
        history: UsageBillingHistoryResponse?,
        failed: Boolean,
    ) {
        binding.historyList.removeAllViews()
        if (!billing.canUseAiClassifiers) {
            showHistoryMessage(getString(R.string.usage_billing_none))
            return
        }
        if (history == null) {
            binding.spendSection.isVisible = false
            showHistoryMessage(getString(if (failed) R.string.usage_billing_load_failed else R.string.loading))
            return
        }
        renderSpend(history)
        if (!binding.limitInput.hasFocus()) binding.limitInput.setText(formatLimit(history.usageBillingLimit))

        val invoices = history.invoices.orEmpty()
        val upcoming = history.upcomingInvoice
        if (invoices.isEmpty() && upcoming == null) {
            showHistoryMessage(getString(R.string.usage_billing_no_invoices))
            return
        }
        binding.historyMessage.isVisible = false
        upcoming?.let { addInvoiceRow(it, it.amount, getString(R.string.usage_billing_upcoming), scheduled = true) }
        for (invoice in invoices) {
            addInvoiceRow(invoice, invoice.amountPaid, getString(R.string.usage_billing_provider), scheduled = invoice.status == "draft")
        }
    }

    private fun showHistoryMessage(message: String) {
        binding.historyMessage.text = message
        binding.historyMessage.isVisible = true
    }

    private fun renderSpend(history: UsageBillingHistoryResponse) {
        val spend = history.currentCycleSpend ?: 0.0
        binding.spendSection.isVisible = true
        binding.spendAmount.text = UsageBilling.formatDollars(spend)
        val (start, end) = billingCycle(history.cycleStart, history.cycleEnd)
        binding.spendPeriod.text =
            getString(R.string.usage_billing_period, formatDate(start, "MMMd"), formatDate(end, "yMMMd"))

        val limit = history.usageBillingLimit
        binding.limitBar.isVisible = limit != null && limit > 0
        binding.limitReachedNote.isVisible = limit != null && history.isLimitReached
        if (limit != null && limit > 0) {
            val fraction = (spend / limit).coerceIn(0.0, 1.0)
            val fill =
                when {
                    history.isLimitReached -> colors.progressLimit
                    fraction > 0.8 -> colors.progressWarning
                    else -> colors.progressFill
                }
            binding.limitBarFill.background = rounded(fill, radiusDp = 6)
            binding.limitBarText.text =
                getString(R.string.usage_billing_limit_progress, UsageBilling.formatDollars(spend), UsageBilling.formatDollars(limit))
            binding.limitBar.post {
                binding.limitBarFill.layoutParams = binding.limitBarFill.layoutParams.apply { width = (binding.limitBar.width * fraction).roundToInt() }
            }
        }
        val upcoming = history.upcomingInvoice
        binding.upcomingCharge.isVisible = upcoming != null
        if (upcoming != null) {
            binding.upcomingCharge.text = getString(R.string.usage_billing_upcoming_charge, UsageBilling.formatDollars(upcoming.amount))
        }
    }

    private fun addInvoiceRow(
        invoice: UsageInvoice,
        amount: Double,
        provider: String,
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
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(10) }
                alpha = if (scheduled) 0.7f else 1f
            }
        header.addView(text(invoice.date?.let { formatDate(parseDate(it), "yMMMMdd") }.orEmpty(), colors.textPrimary, 14f), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        header.addView(text(UsageBilling.formatDollars(amount), colors.textPrimary, 14f, bold = true))
        header.addView(
            text(provider, colors.textSecondary, 13f),
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { marginStart = dp(8) },
        )
        binding.historyList.addView(header)

        invoice.hostedInvoiceUrl?.takeIf { it.startsWith("https://") }?.let { url ->
            binding.historyList.addView(
                text(getString(R.string.usage_billing_invoice), colors.accent, 13f, bold = true).apply {
                    setPadding(0, dp(4), 0, dp(4))
                    setOnClickListener { UIUtils.handleUri(this@UsageBillingActivity, prefsRepo, Uri.parse(url)) }
                },
            )
        }
        for (item in invoice.lineItems.orEmpty()) {
            val row =
                LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(2) }
                }
            row.addView(text(item.description.orEmpty(), colors.textSecondary, 12f), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            row.addView(text(getString(R.string.usage_billing_quantity, NumberFormat.getIntegerInstance().format(item.quantity)), colors.textSecondary, 12f))
            row.addView(
                text(UsageBilling.formatDollars(item.amount), colors.textSecondary, 12f),
                LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { marginStart = dp(8) },
            )
            binding.historyList.addView(row)
        }
    }

    private fun text(
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
        binding.billingCard.background = rounded(colors.cardBackground, colors.cardBorder, radiusDp = 10)
        binding.historyCard.background = rounded(colors.cardBackground, colors.cardBorder, radiusDp = 10)
        listOf(binding.billingTitle, binding.historyTitle, binding.spendAmount, binding.limitLabel, binding.limitDollar, binding.limitBarText)
            .forEach { it.setTextColor(colors.textPrimary) }
        listOf(binding.billingStatus, binding.spendPeriod, binding.upcomingCharge, binding.limitPerMonth, binding.limitHelp, binding.historyMessage)
            .forEach { it.setTextColor(colors.textSecondary) }
        binding.limitReachedNote.setTextColor(colors.limitBannerText)
        binding.limitBar.background = rounded(colors.progressTrack, radiusDp = 6)
        binding.limitInput.background = rounded(colors.inputBackground, colors.cardBorder, radiusDp = 6)
        binding.limitInput.setTextColor(colors.textPrimary)
        binding.limitInput.setHintTextColor(colors.textSecondary)
        listOf(binding.billingButton, binding.limitSave).forEach {
            it.backgroundTintList = ColorStateList.valueOf(colors.accent)
            it.setTextColor(colors.accentText)
        }
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

    /** The cycle's first and last day, defaulting to the current month like reader_account.js. */
    private fun billingCycle(
        start: String?,
        end: String?,
    ): Pair<Date, Date> {
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.DAY_OF_MONTH, 1)
        val monthStart = calendar.time
        calendar.set(Calendar.DAY_OF_MONTH, calendar.getActualMaximum(Calendar.DAY_OF_MONTH))
        val monthEnd = calendar.time
        return (start?.let(::parseDate) ?: monthStart) to (end?.let(::parseDate) ?: monthEnd)
    }

    private fun parseDate(value: String): Date? =
        try {
            SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(value)
        } catch (_: java.text.ParseException) {
            null
        }

    private fun formatDate(
        date: Date?,
        skeleton: String,
    ): String {
        if (date == null) return ""
        val locale = resources.configuration.locales[0]
        return SimpleDateFormat(DateFormat.getBestDateTimePattern(locale, skeleton), locale).format(date)
    }

    private fun formatLimit(limit: Double?): String =
        when {
            limit == null -> ""
            limit % 1.0 == 0.0 -> limit.toLong().toString()
            else -> String.format(Locale.US, "%.2f", limit)
        }
}
