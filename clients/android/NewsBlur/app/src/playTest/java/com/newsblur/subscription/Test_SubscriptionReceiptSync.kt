package com.newsblur.subscription

import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesResponseListener
import com.android.billingclient.api.QueryPurchasesParams
import com.newsblur.network.UserApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.AppConstants
import com.newsblur.util.Log
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test

/**
 * Test_SubscriptionReceiptSync.kt: SubscriptionManager.kt posts an active Play subscription's receipt when the
 * synced profile is missing that plan. An Archive account that upgraded to Archive Extra is already is_archive.
 */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class Test_SubscriptionReceiptSync {
    private val billingClient = mockk<BillingClient>(relaxed = true)
    private val userApi = mockk<UserApi>()
    private val prefs = mockk<PrefsRepo>()

    @Before
    fun setUp() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        mockkStatic(Log::class)
        every { Log.d(any<Any>(), any()) } returns Unit
        mockkStatic(BillingClient::class)
        val builder = mockk<BillingClient.Builder>()
        every { BillingClient.newBuilder(any()) } returns builder
        every { builder.setListener(any()) } returns builder
        every { builder.enablePendingPurchases(any()) } returns builder
        every { builder.build() } returns billingClient
        coEvery { userApi.saveReceipt(any(), any()) } returns null
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
        unmockkAll()
    }

    @Test
    fun test_archive_account_with_an_extra_purchase_posts_the_extra_receipt() {
        syncWithPlayPurchase(AppConstants.PREMIUM_ARCHIVE_EXTRA_SUB_ID, isArchiveExtra = false)

        coVerify(exactly = 1) { userApi.saveReceipt("GPA.1", AppConstants.PREMIUM_ARCHIVE_EXTRA_SUB_ID) }
    }

    @Test
    fun test_extra_account_does_not_post_its_receipt_again() {
        syncWithPlayPurchase(AppConstants.PREMIUM_ARCHIVE_EXTRA_SUB_ID, isArchiveExtra = true)

        coVerify(exactly = 0) { userApi.saveReceipt(any(), any()) }
    }

    private fun syncWithPlayPurchase(
        productId: String,
        isArchiveExtra: Boolean,
    ) {
        every { prefs.getIsPremium() } returns true
        every { prefs.getIsArchive() } returns true
        every { prefs.getIsArchiveExtra() } returns isArchiveExtra
        every { prefs.getIsPro() } returns false
        val purchase =
            mockk<Purchase> {
                every { products } returns listOf(productId)
                every { orderId } returns "GPA.1"
            }
        every { billingClient.queryPurchasesAsync(any<QueryPurchasesParams>(), any()) } answers {
            secondArg<PurchasesResponseListener>().onQueryPurchasesResponse(mockk(), listOf(purchase))
        }
        // runBlocking waits for every coroutine the manager launches in its scope, the receipt post included.
        runBlocking {
            SubscriptionManagerImpl(
                context = mockk(relaxed = true),
                userApi = userApi,
                prefRepository = prefs,
                syncServiceState = mockk(relaxed = true),
                scope = this,
            ).syncActiveSubscription()
        }
    }
}
