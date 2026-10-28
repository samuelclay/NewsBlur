package com.newsblur.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

// Test_UsageBilling.kt: the Stripe return link, the platform the server maps to that link, and
// which billing action each account state offers.
class Test_UsageBilling {
    @Test
    fun test_alpha_builds_use_their_own_platform_and_scheme() {
        assertEquals("android", UsageBilling.platform("com.newsblur"))
        assertEquals("newsblur-auth-android", UsageBilling.callbackScheme("com.newsblur"))
        assertEquals("android-alpha", UsageBilling.platform("com.newsblur.alpha"))
        assertEquals("newsblur-auth-android-alpha", UsageBilling.callbackScheme("com.newsblur.alpha"))
    }

    @Test
    fun test_stripe_return_links_parse_each_status() {
        assertEquals(UsageBillingReturn.SETUP_COMPLETE, UsageBilling.parseReturn("newsblur-auth-android", "usage-billing", "setup_complete", "com.newsblur"))
        assertEquals(UsageBillingReturn.CANCELLED, UsageBilling.parseReturn("newsblur-auth-android", "usage-billing", "cancelled", "com.newsblur"))
        assertEquals(UsageBillingReturn.PORTAL_RETURN, UsageBilling.parseReturn("newsblur-auth-android", "usage-billing", "portal_return", "com.newsblur"))
        assertEquals(
            UsageBillingReturn.SETUP_COMPLETE,
            UsageBilling.parseReturn("newsblur-auth-android-alpha", "usage-billing", "setup_complete", "com.newsblur.alpha"),
        )
    }

    @Test
    fun test_other_links_are_not_billing_returns() {
        assertNull("Social sign-in uses the same scheme", UsageBilling.parseReturn("newsblur-auth-android", "complete", "setup_complete", "com.newsblur"))
        assertNull(UsageBilling.parseReturn("newsblur-auth-android", "usage-billing", "paid", "com.newsblur"))
        assertNull(UsageBilling.parseReturn("newsblur-auth-android", "usage-billing", null, "com.newsblur"))
        assertNull("The release app ignores the alpha scheme", UsageBilling.parseReturn("newsblur-auth-android-alpha", "usage-billing", "cancelled", "com.newsblur"))
        assertNull(UsageBilling.parseReturn("https", "usage-billing", "cancelled", "com.newsblur"))
    }

    @Test
    fun test_billing_action_follows_the_web_branches() {
        assertEquals(UsageBillingAction.SET_UP, UsageBillingState().action)
        assertEquals(UsageBillingAction.MANAGE, UsageBillingState(isUsageBilling = true, canUseAiClassifiers = true).action)
        assertEquals("Self-hosted AI has no billing buttons", UsageBillingAction.NONE, UsageBillingState(isSelfHostedAi = true, canUseAiClassifiers = true).action)
        assertEquals(UsageBillingAction.MANAGE, UsageBillingState(isUsageBilling = true, isSelfHostedAi = true).action)
    }

    @Test
    fun test_costs_format_like_the_web_trainer() {
        assertEquals("$0.00", UsageBilling.formatCost(0.0))
        assertEquals("$0.0004", UsageBilling.formatCost(0.0004))
        assertEquals("$0.032", UsageBilling.formatCost(0.032))
        assertEquals("$1.25", UsageBilling.formatCost(1.25))
        assertEquals("$12.50", UsageBilling.formatDollars(12.5))
    }
}
