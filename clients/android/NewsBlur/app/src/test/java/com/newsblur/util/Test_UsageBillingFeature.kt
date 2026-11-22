package com.newsblur.util

import com.newsblur.network.domain.AiCredits
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// Test_UsageBillingFeature.kt: with UsageBillingFeature.kt's switch off, the app names no way to pay
// outside Google Play: no Stripe button, session, invoice link or editable limit, while a reader
// who already has usage billing still sees it. With the switch on everything is back.
class Test_UsageBillingFeature {
    private val offered = AiCredits(included = 50, isBillingAvailable = true)
    private val billing = AiCredits(included = 50, isBillingAvailable = true, isUsageBilling = true, monthlyLimit = 5.0)
    private val selfHosted = AiCredits(isUnlimited = true, isBillingAvailable = true)

    @Test
    fun test_held_billing_has_no_stripe_path() {
        listOf(offered, billing, selfHosted, null).forEach {
            assertEquals("$it", UsageBillingAction.NONE, UsageBillingFeature.action(it, enabled = false))
            assertFalse("$it", UsageBillingFeature.editsLimit(it, enabled = false))
            assertFalse("$it", UsageBillingFeature.cancels(it, enabled = false))
        }
        assertFalse(UsageBillingFeature.startsStripe(enabled = false))
        assertFalse(UsageBillingFeature.linksInvoices(enabled = false))
    }

    @Test
    fun test_held_billing_still_shows_billing_that_is_on() {
        assertTrue("This month's charges and the limit show read-only", UsageBillingFeature.showsBillingSection(billing, enabled = false))
        assertFalse("Nothing offers it to anyone else", UsageBillingFeature.showsBillingSection(offered, enabled = false))
    }

    @Test
    fun test_billing_switched_on_offers_setup_then_management() {
        assertEquals(UsageBillingAction.SET_UP, UsageBillingFeature.action(offered, enabled = true))
        assertTrue(UsageBillingFeature.showsBillingSection(offered, enabled = true))
        assertFalse("No limit before there's billing to cap", UsageBillingFeature.editsLimit(offered, enabled = true))
        assertFalse(UsageBillingFeature.cancels(offered, enabled = true))

        assertEquals(UsageBillingAction.MANAGE, UsageBillingFeature.action(billing, enabled = true))
        assertTrue(UsageBillingFeature.editsLimit(billing, enabled = true))
        assertTrue(UsageBillingFeature.cancels(billing, enabled = true))

        assertTrue(UsageBillingFeature.startsStripe(enabled = true))
        assertTrue(UsageBillingFeature.linksInvoices(enabled = true))
        assertFalse("A self-hosted server has no billing", UsageBillingFeature.showsBillingSection(selfHosted, enabled = true))
    }
}
