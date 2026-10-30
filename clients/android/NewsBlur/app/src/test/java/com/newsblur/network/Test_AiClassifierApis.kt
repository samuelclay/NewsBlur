package com.newsblur.network

import com.google.gson.Gson
import com.newsblur.domain.ValueMultimap
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
// apps/analyzer/views.py and apps/profile/views.py expect and read their mocked responses.
// No request here reaches a server; testing a prompt costs money in production.
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
        coEvery { networkClient.get(capture(urls), capture(bodies)) } returns response
    }

    @Test
    fun test_text_prompt_test_posts_prompt_and_reads_match() =
        runTest {
            respond("""{"code": 0, "classification": 1, "cost_estimate": {"avg_cost_per_text": 0.0004, "avg_cost_per_image": 0.002}}""")

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
            assertEquals(0.0004, result.costEstimate!!.avgCostPerText, 0.0)
        }

    @Test
    fun test_image_prompt_test_reads_per_image_results() =
        runTest {
            respond("""{"code": 0, "classification": 1, "image_results": [0, 1, 1], "cost_estimate": {}}""")

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
            respond("""{"code": -1, "message": "Usage billing required for AI classifiers"}""")
            val refused = classifierApi.testPrompt(PromptTestRequest("x", "1:a", null, includeImages = false, hidden = false))
            assertFalse(refused.isSuccess)
            assertEquals("Usage billing required for AI classifiers", refused.message)
            assertTrue("A missing feed id is sent as 0", "feed_id=0" in form(bodies.last()))

            respond(null)
            val offline = classifierApi.testPrompt(PromptTestRequest("x", "1:a", null, includeImages = false, hidden = false))
            assertFalse(offline.isSuccess)
            assertNull(offline.message)

            respond("<html>502</html>")
            assertFalse(classifierApi.testPrompt(PromptTestRequest("x", "1:a", null, includeImages = false, hidden = false)).isSuccess)
        }

    @Test
    fun test_ai_usage_reads_costs_and_limit() =
        runTest {
            respond(
                """{"code": 0, "can_use_ai": true, "avg_cost_per_text": 0.0003, "avg_cost_per_image": 0.0021,
                   "current_cycle_spend": 4.5, "usage_billing_limit": 5.0, "is_limit_reached": false}""",
            )

            val usage = classifierApi.getAiClassifierUsage("42")

            assertEquals(APIConstants.buildUrl(APIConstants.PATH_CLASSIFIER_AI_USAGE), urls.single())
            assertEquals("feed_id=42", form(bodies.single()))
            assertTrue(usage.canUseAi)
            assertEquals(0.0021, usage.costEstimate.avgCostPerImage, 0.0)
            assertEquals(5.0, usage.usageBillingLimit!!, 0.0)
            assertFalse(usage.isLimitReached)

            respond("""{"code": 0, "can_use_ai": false}""")
            assertFalse(classifierApi.getAiClassifierUsage("42").canUseAi)
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
    fun test_billing_limit_save_sends_trimmed_limit_and_reads_result() =
        runTest {
            respond("""{"code": 1, "limit": 25.0}""")
            val saved = billingApi.saveLimit(" 25 ")
            assertEquals(APIConstants.buildUrl(APIConstants.PATH_SAVE_USAGE_BILLING_LIMIT), urls.single())
            assertEquals("limit=25", form(bodies.single()))
            assertTrue(saved.isSaved)
            assertEquals(25.0, saved.limit!!, 0.0)

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
    fun test_billing_history_reads_spend_invoices_and_upcoming_charge() =
        runTest {
            respond(
                """
                {"invoices": [{"date": "2026-09-30", "amount": 3.1, "amount_paid": 3.1, "status": "paid",
                  "hosted_invoice_url": "https://invoice.stripe.com/i/1", "invoice_number": "NB-1",
                  "line_items": [{"description": "Natural language text classifier", "quantity": 1200, "amount": 2.4}]}],
                 "upcoming_invoice": {"date": "2026-10-31", "amount": 1.25, "status": "upcoming", "line_items": []},
                 "current_cycle_spend": 1.25, "usage_billing_limit": null, "is_limit_reached": false,
                 "cycle_start": "2026-10-01", "cycle_end": "2026-10-31"}
                """.trimIndent(),
            )

            val history = billingApi.getHistory()!!

            assertEquals(APIConstants.buildUrl(APIConstants.PATH_USAGE_BILLING_HISTORY), urls.single())
            assertEquals(1.25, history.currentCycleSpend!!, 0.0)
            assertNull(history.usageBillingLimit)
            assertEquals("2026-10-01", history.cycleStart)
            assertEquals(1200L, history.invoices!!.single().lineItems!!.single().quantity)
            assertEquals("https://invoice.stripe.com/i/1", history.invoices!!.single().hostedInvoiceUrl)
            assertEquals(1.25, history.upcomingInvoice!!.amount, 0.0)

            respond(null)
            assertNull(billingApi.getHistory())
        }

    private fun form(values: ValueMultimap): String = Buffer().also { values.asFormEncodedRequestBody().writeTo(it) }.readUtf8()
}
