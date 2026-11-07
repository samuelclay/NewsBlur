package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// Test_UsageBillingFeature.kt: with UsageBillingFeature.kt's switch off, no billing button, link
// or card shows and UsageBillingActivity.kt won't open, and with it on everything is back.
class Test_UsageBillingFeature {
    private val noBilling = UsageBillingState()
    private val withBilling = UsageBillingState(isUsageBilling = true, canUseAiClassifiers = true)
    private val selfHosted = UsageBillingState(isSelfHostedAi = true, canUseAiClassifiers = true)

    @Test
    fun test_held_billing_hides_the_premium_card_and_the_billing_screen() {
        assertFalse(UsageBillingFeature.showsPremiumCard(enabled = false))
        assertFalse(UsageBillingFeature.opensBillingScreen(enabled = false))

        assertTrue(UsageBillingFeature.showsPremiumCard(enabled = true))
        assertTrue(UsageBillingFeature.opensBillingScreen(enabled = true))
    }

    @Test
    fun test_held_billing_keeps_the_cost_box_without_a_billing_button() {
        listOf(noBilling, withBilling, selfHosted).forEach {
            assertEquals("$it", UsageBillingAction.NONE, UsageBillingFeature.costBoxAction(it, enabled = false))
        }

        assertEquals(UsageBillingAction.SET_UP, UsageBillingFeature.costBoxAction(noBilling, enabled = true))
        assertEquals(UsageBillingAction.MANAGE, UsageBillingFeature.costBoxAction(withBilling, enabled = true))
        assertEquals(UsageBillingAction.NONE, UsageBillingFeature.costBoxAction(selfHosted, enabled = true))
    }

    @Test
    fun test_held_billing_banners_state_the_situation_without_a_link() {
        val limit = UsageBillingFeature.banner(limitReached = true, hasPrompts = true, canUseAiClassifiers = true, enabled = false)
        val inactive = UsageBillingFeature.banner(limitReached = false, hasPrompts = true, canUseAiClassifiers = false, enabled = false)

        assertEquals(UsageBillingBanner.LIMIT_REACHED, limit)
        assertEquals("Says why saved filters don't run, naming no purchase path", UsageBillingBanner.NOT_ACTIVE, inactive)
        for (limitReached in listOf(true, false)) {
            for (hasPrompts in listOf(true, false)) {
                for (canUse in listOf(true, false)) {
                    val banner = UsageBillingFeature.banner(limitReached, hasPrompts, canUse, enabled = false)
                    assertFalse("$banner links to billing", banner.linksToBilling)
                }
            }
        }
    }

    @Test
    fun test_enabled_billing_banners_link_to_billing_like_the_web() {
        assertEquals(
            UsageBillingBanner.LIMIT_REACHED_WITH_LINK,
            UsageBillingFeature.banner(limitReached = true, hasPrompts = true, canUseAiClassifiers = true, enabled = true),
        )
        assertEquals(
            UsageBillingBanner.SET_UP_BILLING,
            UsageBillingFeature.banner(limitReached = false, hasPrompts = true, canUseAiClassifiers = false, enabled = true),
        )
        assertTrue(UsageBillingBanner.LIMIT_REACHED_WITH_LINK.linksToBilling)
        assertTrue(UsageBillingBanner.SET_UP_BILLING.linksToBilling)
    }

    @Test
    fun test_no_banner_without_prompts_or_with_ai_running() {
        listOf(true, false).forEach { enabled ->
            assertEquals(
                UsageBillingBanner.NONE,
                UsageBillingFeature.banner(limitReached = false, hasPrompts = false, canUseAiClassifiers = false, enabled = enabled),
            )
            assertEquals(
                UsageBillingBanner.NONE,
                UsageBillingFeature.banner(limitReached = false, hasPrompts = true, canUseAiClassifiers = true, enabled = enabled),
            )
        }
    }
}
