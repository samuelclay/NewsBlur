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
    private val forecast = AiCreditsForecast(credits = 12_100.0, creditsPerDay = 400.0, runsOutOn = "2026-11-27", overageUsd = 0.11)
    private val free = AiCredits(included = 0, isPaused = true, pauseReason = "plan", isBillingAvailable = true)
    private val running = AiCredits(included = 10_000, used = 2_468.0, isBillingAvailable = true)
    private val warning = running.copy(used = 8_400.0, isWarning = true, forecast = forecast)
    private val pausedCredits = running.copy(used = 10_000.0, isWarning = true, isPaused = true, pauseReason = "credits", forecast = forecast)
    private val billing = running.copy(used = 17_400.0, isUsageBilling = true, overageCredits = 7_400, overageUsd = 0.07, forecast = forecast)
    private val pausedLimit = billing.copy(monthlyLimit = 0.05, isPaused = true, pauseReason = "limit")
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
    fun test_the_meter_reads_past_the_plan_only_when_the_shown_numbers_are() {
        assertTrue(AiCreditsStatus.isPastPlan(billing.copy(used = 12_340.0)))
        assertEquals(2_340.0, AiCreditsStatus.pastPlanCredits(billing.copy(used = 12_340.0)), 0.0)
        assertFalse("10,000.4 shows as 10,000 of 10,000", AiCreditsStatus.isPastPlan(running.copy(used = 10_000.4)))
        assertEquals(0.0, AiCreditsStatus.pastPlanCredits(running.copy(used = 10_000.4)), 0.0)
        assertTrue("10,000.6 shows as 10,001", AiCreditsStatus.isPastPlan(running.copy(used = 10_000.6)))
        assertFalse("A free plan has no credits to be past", AiCreditsStatus.isPastPlan(billing.copy(included = 0)))
    }

    @Test
    fun test_only_usage_billing_past_the_plan_splits_the_bar() {
        assertEquals("The plan's 10,000 of 17,400 used", 10_000 / 17_400f, AiCreditsStatus.planShare(billing)!!, 0.0001f)
        assertEquals("Paused at the limit still splits", 10_000 / 17_400f, AiCreditsStatus.planShare(pausedLimit)!!, 0.0001f)
        assertNull("Paused for credits has nothing billed", AiCreditsStatus.planShare(pausedCredits.copy(used = 10_050.0)))
        assertNull("Usage billing within the plan is one color", AiCreditsStatus.planShare(billing.copy(used = 4_000.0)))
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
    fun test_credits_are_whole_numbers_grouped_in_the_reader_s_language() {
        assertEquals("12,340", AiCreditsStatus.formatCredits(12_340.4, Locale.US))
        assertEquals("12.340", AiCreditsStatus.formatCredits(12_340.0, Locale.GERMANY))
        assertEquals("100,000", AiCreditsStatus.formatPlanCredits(AiCreditsStatus.PRO_CREDITS, Locale.US))
    }

    @Test
    fun test_the_billing_rate_follows_the_server_s_credit_price() {
        assertEquals(1_000, AiCreditsStatus.creditsPerCent(running.copy(creditUsd = 0.00001)))
        assertEquals("A price change reaches the wording without an app update", 500, AiCreditsStatus.creditsPerCent(running.copy(creditUsd = 0.00002)))
    }

    @Test
    fun test_a_site_estimate_is_whole_credits_or_less_than_one() {
        assertEquals(1_372, AiCreditsStatus.estimateCredits(1_371.6))
        assertTrue(AiCreditsStatus.isUnderOneCredit(0.6))
        assertFalse("A credit and a half is at least one", AiCreditsStatus.isUnderOneCredit(1.5))
        assertFalse(AiCreditsStatus.isUnderOneCredit(0.0))
        assertNull("No stories last month, no estimate", AiCreditsStatus.estimateCredits(0.0))
    }
}
