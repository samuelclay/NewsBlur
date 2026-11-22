package com.newsblur.network

import com.google.gson.Gson
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.domain.FeedFolderResponse
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

// Test_AiClassifierApis.kt: ClassifierApiImpl.kt and UsageBillingApiImpl.kt send what
// apps/analyzer/views.py and apps/profile/views.py expect and read their mocked responses,
// including the AI credits in /reader/feeds. No request here reaches a server.
class Test_AiClassifierApis {
    private val networkClient = mockk<NetworkClient>()
    private val classifierApi = ClassifierApiImpl(Gson(), networkClient)
    private val billingApi = UsageBillingApiImpl(Gson(), networkClient)
    private val urls = mutableListOf<String>()
    private val bodies = mutableListOf<ValueMultimap>()

    private fun respond(body: String?) {
        val response = mockk<APIResponse>()
        every { response.isError } returns (body == null)
        every { response.responseBody } returns body
        coEvery { networkClient.post(capture(urls), capture(bodies)) } returns response
        coEvery { networkClient.postWithoutRetry(capture(urls), capture(bodies), any()) } returns response
        coEvery { networkClient.get(capture(urls), capture(bodies)) } returns response
    }

    @Test
    fun test_text_prompt_test_posts_prompt_and_reads_match() =
        runTest {
            respond("""{"code": 0, "classification": 1, "description": "Apple news"}""")

            val result =
                classifierApi.testPrompt(
                    PromptTestRequest("Non-apple related news", "5719953:1b4552", "5719953", includeImages = false, hidden = false),
                )

            assertEquals(APIConstants.buildUrl(APIConstants.PATH_CLASSIFIER_TEST_PROMPT), urls.single())
            val body = form(bodies.single())
            assertTrue(body, "prompt=Non-apple+related+news" in body)
            assertTrue(body, "story_hash=5719953%3A1b4552" in body)
            assertTrue(body, "include_images=false" in body)
            assertTrue(body, "classifier_type=focus" in body)
            assertTrue(body, "feed_id=5719953" in body)
            assertTrue(result.isSuccess)
            assertTrue(result.matched)
        }

    @Test
    fun test_image_prompt_test_reads_per_image_results() =
        runTest {
            respond("""{"code": 0, "classification": 1, "image_results": [0, 1, 1]}""")

            val result = classifierApi.testPrompt(PromptTestRequest("Charts", "1:a", "1", includeImages = true, hidden = true))

            val body = form(bodies.single())
            assertTrue(body, "include_images=true" in body)
            assertTrue(body, "classifier_type=hidden" in body)
            assertFalse(result.imageMatched(0))
            assertTrue(result.imageMatched(1))
            assertFalse("A missing index never counts as a match", result.imageMatched(5))
            assertEquals(2, result.imageMatchCount)
        }

    @Test
    fun test_prompt_test_errors_keep_the_server_message_or_fall_back() =
        runTest {
            respond("""{"code": -1, "message": "Story not found"}""")
            val refused = classifierApi.testPrompt(PromptTestRequest("x", "1:a", null, includeImages = false, hidden = false))
            assertFalse(refused.isSuccess)
            assertEquals("Story not found", refused.message)
            assertTrue("A missing feed id is sent as 0", "feed_id=0" in form(bodies.last()))

            respond(null)
            val offline = classifierApi.testPrompt(PromptTestRequest("x", "1:a", null, includeImages = false, hidden = false))
            assertFalse(offline.isSuccess)
            assertNull(offline.message)

            respond("<html>502</html>")
            assertFalse(classifierApi.testPrompt(PromptTestRequest("x", "1:a", null, includeImages = false, hidden = false)).isSuccess)
        }

    // apps/analyzer/ai_credits.py state() for a Premium Archive reader running low.
    private val creditsJson =
        """{"included": 50, "used": 42.5, "remaining": 7.5, "month": "2026-11", "resets_on": "2026-12-01",
           "is_unlimited": false, "is_billing_available": true, "is_usage_billing": false, "monthly_limit": null,
           "overage_credits": 0, "overage_usd": 0.0, "unbilled_usd": 0.0, "minimum_charge_usd": 1.0,
           "immediate_charge_usd": 10.0, "is_paused": false, "pause_reason": null, "is_warning": true, "credit_usd": 0.01,
           "forecast": {"credits": 61.2, "credits_per_day": 2.1, "runs_out_on": "2026-11-25", "overage_usd": 0.12}}"""

    @Test
    fun test_ai_usage_reads_the_credits_and_the_site_estimates() =
        runTest {
            respond(
                """{"code": 0, "can_use_ai": true, "ai_credits": $creditsJson, "stories_per_month": 300,
                   "text_credits_per_month": 0.42, "image_credits_per_month": 3.0}""",
            )

            val usage = classifierApi.getAiClassifierUsage("42")

            assertEquals(APIConstants.buildUrl(APIConstants.PATH_AI_CLASSIFIER_USAGE), urls.single())
            assertEquals("feed_id=42", form(bodies.single()))
            assertTrue(usage.isSuccess)
            assertEquals(0.42, usage.textCreditsPerMonth, 0.0)
            assertEquals(3.0, usage.imageCreditsPerMonth, 0.0)
            val credits = usage.aiCredits!!
            assertEquals(50, credits.included)
            assertTrue(credits.isWarning)
            assertNull(credits.pauseReason)
            assertEquals("2026-11-25", credits.forecast!!.runsOutOn)
            assertEquals(0.12, credits.forecast!!.overageUsd, 0.0)

            respond(null)
            assertFalse("A failed request never reads as zero usage", classifierApi.getAiClassifierUsage(null).isSuccess)
            assertEquals("The account-wide check sends no site", "feed_id=0", form(bodies.last()))
        }

    @Test
    fun test_reader_feeds_brings_the_credits_with_the_profile() {
        fun profile(extra: String) =
            FeedFolderResponse(
                """{"authenticated": true, "folders": [], "feeds": [],
                   "user_profile": {"is_premium": true, "premium_expire": 0, "is_archive": true $extra}}""",
                Gson(),
            )

        val credits = profile(""", "ai_credits": $creditsJson""").aiCredits!!
        assertEquals("2026-12-01", credits.resetsOn)
        assertEquals(42.5, credits.used, 0.0)
        assertNull("A server from before credits sends none", profile("").aiCredits)
    }

    @Test
    fun test_billing_setup_posts_platform_and_reads_stripe_url() =
        runTest {
            respond("""{"code": 0, "url": "https://checkout.stripe.com/c/pay/cs_test"}""")

            val session = billingApi.startSetup("android-alpha")

            assertEquals(APIConstants.buildUrl(APIConstants.PATH_SETUP_USAGE_BILLING), urls.single())
            assertEquals("platform=android-alpha", form(bodies.single()))
            assertEquals("https://checkout.stripe.com/c/pay/cs_test", session.stripeUrl)
        }

    @Test
    fun test_billing_setup_reports_already_active_and_errors() =
        runTest {
            respond("""{"code": 0, "already_active": true}""")
            val active = billingApi.startSetup("android")
            assertTrue(active.alreadyActive)
            assertNull(active.stripeUrl)

            respond("""{"code": -1, "message": "Couldn't reach Stripe. Please try again."}""")
            val failed = billingApi.openPortal("android")
            assertEquals(APIConstants.buildUrl(APIConstants.PATH_MANAGE_USAGE_BILLING), urls.last())
            assertNull(failed.stripeUrl)
            assertEquals("Couldn't reach Stripe. Please try again.", failed.message)

            respond("""{"code": 0, "url": "javascript:alert(1)"}""")
            assertNull("Only https Stripe links open", billingApi.openPortal("android").stripeUrl)

            respond(null)
            assertNull(billingApi.openPortal("android").stripeUrl)
        }

    @Test
    fun test_billing_limit_save_sends_trimmed_limit_and_reads_the_new_credits() =
        runTest {
            respond("""{"code": 1, "limit": 25.0, "ai_credits": $creditsJson}""")
            val saved = billingApi.saveLimit(" 25 ")
            assertEquals(APIConstants.buildUrl(APIConstants.PATH_SAVE_USAGE_BILLING_LIMIT), urls.single())
            assertEquals("limit=25", form(bodies.single()))
            assertTrue(saved.isSaved)
            assertEquals(25.0, saved.limit!!, 0.0)
            assertEquals(50, saved.aiCredits!!.included)

            respond("""{"code": 1, "limit": null}""")
            val cleared = billingApi.saveLimit("")
            assertEquals("limit=", form(bodies.last()))
            assertTrue(cleared.isSaved)
            assertNull(cleared.limit)

            respond("""{"code": -1, "message": "Limit cannot exceed $10,000"}""")
            val refused = billingApi.saveLimit("20000")
            assertFalse(refused.isSaved)
            assertEquals("Limit cannot exceed $10,000", refused.message)
        }

    @Test
    fun test_turning_billing_off_reads_the_credits_it_leaves() =
        runTest {
            respond("""{"code": 0, "ai_credits": $creditsJson}""")

            val cancelled = billingApi.cancel()

            assertEquals(APIConstants.buildUrl(APIConstants.PATH_CANCEL_USAGE_BILLING), urls.single())
            assertTrue(cancelled.isSuccess)
            assertFalse(cancelled.aiCredits!!.isUsageBilling)

            respond(null)
            assertFalse("A failed request leaves billing on screen as it was", billingApi.cancel().isSuccess)
        }

    @Test
    fun test_billing_history_reads_the_credits_and_invoices() =
        runTest {
            respond(
                """
                {"code": 0, "ai_credits": ${creditsJson.replace("\"unbilled_usd\": 0.0", "\"unbilled_usd\": 0.37")},
                 "invoices": [{"date": "2026-10-01", "amount": 3.1, "amount_paid": 3.1, "status": "paid",
                  "hosted_invoice_url": "https://invoice.stripe.com/i/1", "invoice_number": "NB-1",
                  "line_items": [{"description": "AI credits", "quantity": 310, "amount": 3.1}]}],
                 "upcoming_invoice": null}
                """.trimIndent(),
            )

            val history = billingApi.getHistory()!!

            assertEquals(APIConstants.buildUrl(APIConstants.PATH_USAGE_BILLING_HISTORY), urls.single())
            assertEquals(0.37, history.aiCredits!!.unbilledUsd, 0.0)
            assertEquals(310L, history.invoices!!.single().lineItems!!.single().quantity)
            assertEquals("https://invoice.stripe.com/i/1", history.invoices!!.single().hostedInvoiceUrl)
            assertNull(history.upcomingInvoice)

            respond(null)
            assertNull(billingApi.getHistory())
            respond("""{"code": -1}""")
            assertNull("A refused request is a failure, not an empty history", billingApi.getHistory())
        }

    private fun form(values: ValueMultimap): String = Buffer().also { values.asFormEncodedRequestBody().writeTo(it) }.readUtf8()
}
