package com.newsblur.util

import com.newsblur.network.domain.AiCredits
import kotlinx.coroutines.test.currentTime
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Locale

// Test_UsageBilling.kt: the Stripe return link, the platform the server maps to that link, which
// usage billing button each account's credits offer, and the monthly limit field's round trip.
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
    fun test_the_billing_button_follows_the_credits() {
        assertEquals(UsageBillingAction.SET_UP, UsageBilling.action(AiCredits(included = 50, isBillingAvailable = true)))
        assertEquals(UsageBillingAction.MANAGE, UsageBilling.action(AiCredits(included = 50, isBillingAvailable = true, isUsageBilling = true)))
        assertEquals(
            "A server without the AI credit price offers no setup",
            UsageBillingAction.NONE,
            UsageBilling.action(AiCredits(included = 50, isBillingAvailable = false)),
        )
        assertEquals(
            "Usage billing that's on can still be managed while the server stops offering it",
            UsageBillingAction.MANAGE,
            UsageBilling.action(AiCredits(included = 50, isBillingAvailable = false, isUsageBilling = true)),
        )
        assertEquals(
            "A self-hosted server counts no credits",
            UsageBillingAction.NONE,
            UsageBilling.action(AiCredits(isUnlimited = true, isBillingAvailable = true)),
        )
        assertEquals("Nothing synced yet", UsageBillingAction.NONE, UsageBilling.action(null))
    }

    @Test
    fun test_usage_billing_amounts_are_dollars_in_every_language() {
        assertEquals("$0.62", UsageBilling.formatDollars(0.62, Locale.US))
        val german = UsageBilling.formatDollars(0.62, Locale.GERMANY)
        assertTrue("A German reader is charged dollars, not euros: $german", "$" in german && "€" !in german)
        assertTrue("with a German decimal comma: $german", "0,62" in german)
    }

    @Test
    fun test_activation_rechecks_with_backoff_until_the_webhook_lands() =
        runTest {
            val checkedAt = mutableListOf<Long>()

            val active =
                UsageBilling.awaitActivation {
                    checkedAt.add(currentTime)
                    checkedAt.size == 3
                }

            assertTrue(active)
            assertEquals("Checks right away, then after 1s and 2s more", listOf(0L, 1_000L, 3_000L), checkedAt)
        }

    @Test
    fun test_activation_gives_up_after_the_backoff_without_failing() =
        runTest {
            var checks = 0

            val active =
                UsageBilling.awaitActivation {
                    checks++
                    false
                }

            assertFalse(active)
            assertEquals(4, checks)
            assertEquals("1s, 2s and 4s of backoff", 7_000L, currentTime)
        }

    private val german = Locale.GERMANY
    private val english = Locale.US

    @Test
    fun test_a_german_limit_with_a_decimal_comma_saves_as_a_decimal_point() {
        assertEquals("10.50", UsageBilling.normalizeLimit("10,50", german))
        assertEquals("10.50", UsageBilling.normalizeLimit("10,5", german))
        assertEquals("A keyboard that sends a point still works", "10.50", UsageBilling.normalizeLimit("10.50", german))
        assertEquals("1000.50", UsageBilling.normalizeLimit("1.000,50", german))
    }

    @Test
    fun test_an_english_limit_saves_as_typed() {
        assertEquals("10.50", UsageBilling.normalizeLimit(" 10.50 ", english))
        assertEquals("25.00", UsageBilling.normalizeLimit("25", english))
        assertEquals("0.50", UsageBilling.normalizeLimit(".5", english))
        assertEquals("1000.50", UsageBilling.normalizeLimit("1,000.50", english))
    }

    @Test
    fun test_a_blank_limit_clears_it() {
        assertEquals("", UsageBilling.normalizeLimit("", english))
        assertEquals("", UsageBilling.normalizeLimit("   ", german))
    }

    @Test
    fun test_text_that_is_not_an_amount_is_never_sent() {
        assertNull("Three digits after the separator is ambiguous", UsageBilling.normalizeLimit("1,000", english))
        assertNull(UsageBilling.normalizeLimit("10,505", german))
        assertNull(UsageBilling.normalizeLimit("1,2,3", english))
        assertNull(UsageBilling.normalizeLimit(".", english))
        assertNull(UsageBilling.normalizeLimit("1.000,50", english))
        assertNull(UsageBilling.normalizeLimit("ten", english))
    }

    @Test
    fun test_a_saved_limit_shows_in_the_locale_and_reads_back() {
        assertEquals("10,50", UsageBilling.formatLimit(10.5, german))
        assertEquals("10.50", UsageBilling.formatLimit(10.5, english))
        assertEquals("25", UsageBilling.formatLimit(25.0, german))
        assertEquals("", UsageBilling.formatLimit(null, german))
        assertEquals("10.50", UsageBilling.normalizeLimit(UsageBilling.formatLimit(10.5, german), german))
    }
}
