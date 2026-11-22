package com.newsblur.util

import com.newsblur.network.domain.AiCredits
import com.newsblur.network.domain.AiCreditsForecast
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

// Test_AiCreditsStatus.kt: apps/analyzer/ai_credits.py state() maps onto one credit state, each
// state's trainer button goes where the AI credits spec says, and none leads to Stripe while
// UsageBillingFeature.kt holds usage billing.
class Test_AiCreditsStatus {
    private val forecast = AiCreditsForecast(credits = 61.0, creditsPerDay = 2.0, runsOutOn = "2026-11-27", overageUsd = 0.11)
    private val free = AiCredits(included = 0, isPaused = true, pauseReason = "plan", isBillingAvailable = true)
    private val running = AiCredits(included = 50, used = 12.34, isBillingAvailable = true)
    private val warning = running.copy(used = 42.0, isWarning = true, forecast = forecast)
    private val pausedCredits = running.copy(used = 50.0, isWarning = true, isPaused = true, pauseReason = "credits", forecast = forecast)
    private val billing = running.copy(used = 87.0, isUsageBilling = true, overageCredits = 37, overageUsd = 0.37, forecast = forecast)
    private val pausedLimit = billing.copy(monthlyLimit = 5.0, isPaused = true, pauseReason = "limit")
    private val unlimited = AiCredits(isUnlimited = true)

    @Test
    fun test_each_server_state_is_one_credit_state() {
        assertEquals(AiCreditsStage.FREE, AiCreditsStatus.stage(free))
        assertEquals(AiCreditsStage.RUNNING, AiCreditsStatus.stage(running))
        assertEquals(AiCreditsStage.WARNING, AiCreditsStatus.stage(warning))
        assertEquals(AiCreditsStage.PAUSED_CREDITS, AiCreditsStatus.stage(pausedCredits))
        assertEquals(AiCreditsStage.USAGE_BILLING, AiCreditsStatus.stage(billing))
        assertEquals(AiCreditsStage.PAUSED_LIMIT, AiCreditsStatus.stage(pausedLimit))
        assertEquals(AiCreditsStage.HIDDEN, AiCreditsStatus.stage(unlimited))
        assertEquals("Nothing synced yet", AiCreditsStage.HIDDEN, AiCreditsStatus.stage(null))
    }

    @Test
    fun test_usage_billing_near_its_limit_is_still_billing_not_low_credits() {
        // ai_credits.py sets is_warning near the monthly limit too, but the credits are long gone.
        val nearLimit = billing.copy(monthlyLimit = 1.0, isWarning = true)

        assertEquals(AiCreditsStage.USAGE_BILLING, AiCreditsStatus.stage(nearLimit))
        assertEquals(AiCreditsMeterLevel.WARNING, AiCreditsStatus.meterLevel(nearLimit))
        assertNull("Billed credits never run out", AiCreditsStatus.runsOutOn(nearLimit))
    }

    @Test
    fun test_a_pause_this_build_does_not_know_still_reads_as_paused() {
        assertEquals(AiCreditsStage.PAUSED_CREDITS, AiCreditsStatus.stage(running.copy(isPaused = true, pauseReason = "abuse")))
    }

    @Test
    fun test_held_billing_leaves_only_the_upgrade_button() {
        assertEquals(AiCreditsAction.UPGRADE, AiCreditsStatus.trainerAction(free, billingEnabled = false))
        listOf(running, warning, pausedCredits, billing, pausedLimit, unlimited).forEach {
            assertNull("$it", AiCreditsStatus.trainerAction(it, billingEnabled = false))
        }
    }

    @Test
    fun test_billing_switched_on_gives_each_state_its_button() {
        assertEquals(AiCreditsAction.UPGRADE, AiCreditsStatus.trainerAction(free, billingEnabled = true))
        assertNull(AiCreditsStatus.trainerAction(running, billingEnabled = true))
        assertEquals(AiCreditsAction.SET_UP_BILLING, AiCreditsStatus.trainerAction(warning, billingEnabled = true))
        assertEquals(AiCreditsAction.SET_UP_BILLING, AiCreditsStatus.trainerAction(pausedCredits, billingEnabled = true))
        assertEquals(AiCreditsAction.MANAGE_BILLING, AiCreditsStatus.trainerAction(billing, billingEnabled = true))
        assertEquals(AiCreditsAction.CHANGE_LIMIT, AiCreditsStatus.trainerAction(pausedLimit, billingEnabled = true))
        assertNull(
            "A server without the AI credit price can't set billing up",
            AiCreditsStatus.trainerAction(pausedCredits.copy(isBillingAvailable = false), billingEnabled = true),
        )
    }

    @Test
    fun test_the_meter_fills_up_and_stays_full_past_the_credits() {
        assertEquals(0.2468f, AiCreditsStatus.meterFraction(running), 0.0001f)
        assertEquals(1f, AiCreditsStatus.meterFraction(billing), 0f)
        assertEquals(AiCreditsMeterLevel.NORMAL, AiCreditsStatus.meterLevel(billing))
        assertEquals(AiCreditsMeterLevel.WARNING, AiCreditsStatus.meterLevel(warning))
        assertEquals(AiCreditsMeterLevel.PAUSED, AiCreditsStatus.meterLevel(pausedCredits))
    }

    @Test
    fun test_only_a_plan_with_credits_has_a_meter() {
        assertTrue(AiCreditsStatus.showsMeter(pausedLimit))
        assertFalse(AiCreditsStatus.showsMeter(free))
        assertFalse(AiCreditsStatus.showsMeter(unlimited))
        assertFalse("Usage billing without a plan has nothing to count against", AiCreditsStatus.showsMeter(billing.copy(included = 0)))
    }

    @Test
    fun test_the_run_out_date_shows_only_while_credits_are_running_down() {
        assertEquals("2026-11-27", AiCreditsStatus.runsOutOn(warning))
        assertNull("Already paused", AiCreditsStatus.runsOutOn(pausedCredits))
        assertNull(AiCreditsStatus.runsOutOn(running))
    }

    @Test
    fun test_the_billing_forecast_is_left_out_when_it_would_cost_nothing() {
        assertEquals(0.11, AiCreditsStatus.billingForecastUsd(warning)!!, 0.0)
        assertNull(AiCreditsStatus.billingForecastUsd(warning.copy(forecast = forecast.copy(overageUsd = 0.0))))
        assertNull(AiCreditsStatus.billingForecastUsd(running))
    }

    @Test
    fun test_credits_show_up_to_one_decimal_in_the_reader_s_language() {
        assertEquals("12.3", AiCreditsStatus.formatCredits(12.34, Locale.US))
        assertEquals("12", AiCreditsStatus.formatCredits(12.0, Locale.US))
        assertEquals("12,3", AiCreditsStatus.formatCredits(12.34, Locale.GERMANY))
    }

    @Test
    fun test_a_site_estimate_always_reads_as_an_amount() {
        assertEquals("0.4", AiCreditsStatus.formatEstimate(0.42, Locale.US))
        assertEquals("A whole estimate keeps its decimal so it reads as credits, not one credit", "1.0", AiCreditsStatus.formatEstimate(1.0, Locale.US))
        assertEquals("A tiny estimate doesn't round to nothing", "0.1", AiCreditsStatus.formatEstimate(0.004, Locale.US))
        assertEquals("120", AiCreditsStatus.formatEstimate(120.0, Locale.US))
        assertNull("No stories last month, no estimate", AiCreditsStatus.formatEstimate(0.0, Locale.US))
    }
}
