package com.newsblur.subscription

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.AcknowledgePurchaseResponseListener
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.SkuDetails
import com.android.billingclient.api.SkuDetailsParams
import com.newsblur.R
import com.newsblur.network.APIManager
import com.newsblur.service.NBSyncService
import com.newsblur.util.AppConstants
import com.newsblur.util.FeedUtils
import com.newsblur.util.Log
import com.newsblur.util.NBScope
import com.newsblur.util.PrefsUtils
import com.newsblur.util.executeAsyncTask
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.*

interface SubscriptionManager {

    /**
     * Open connection to Play Store to retrieve
     * purchases and subscriptions.
     */
    fun startBillingConnection(listener: SubscriptionsListener? = null)

    /**
     * Generated subscription state by retrieve all available subscriptions
     * and checking whether the user has an active subscription.
     *
     * Subscriptions are configured via the Play Store console.
     */
    fun syncSubscriptionState()

    /**
     * Launch the billing flow overlay for a specific subscription.
     * @param activity Activity on which the billing overlay will be displayed.
     * @param skuDetails Subscription details for the intended purchases.
     */
    fun purchaseSubscription(activity: Activity, skuDetails: SkuDetails)

    /**
     * Sync subscription state between NewsBlur and Play Store.
     */
    suspend fun syncActiveSubscription(): Job

    /**
     * Notify backend of active Play Store subscription.
     */
    fun saveReceipt(purchase: Purchase)

    suspend fun hasActiveSubscription(): Boolean
}

interface SubscriptionsListener {

    fun onActiveSubscription(renewalMessage: String?) {}

    fun onAvailableSubscription(skuDetails: SkuDetails) {}

    fun onBillingConnectionReady() {}

    fun onBillingConnectionError(message: String? = null) {}
}

@EntryPoint
@InstallIn(SingletonComponent::class)
interface SubscriptionManagerEntryPoint {

    fun apiManager(): APIManager
}

class SubscriptionManagerImpl(
        private val context: Context,
        private val scope: CoroutineScope = NBScope,
) : SubscriptionManager {

    private var listener: SubscriptionsListener? = null

    private val acknowledgePurchaseListener = AcknowledgePurchaseResponseListener { billingResult: BillingResult ->
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                Log.d(this, "acknowledgePurchaseResponseListener OK")
                scope.launch(Dispatchers.Default) {
                    syncActiveSubscription()
                }
            }
            BillingClient.BillingResponseCode.BILLING_UNAVAILABLE -> {
                // Billing API version is not supported for the type requested.
                Log.d(this, "acknowledgePurchaseResponseListener BILLING_UNAVAILABLE")
            }
            BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE -> {
                // Network connection is down.
                Log.d(this, "acknowledgePurchaseResponseListener SERVICE_UNAVAILABLE")
            }
            else -> {
                // Handle any other error codes.
                Log.d(this, "acknowledgePurchaseResponseListener ERROR - message: " + billingResult.debugMessage)
            }
        }
    }

    /**
     * Billing client listener triggered after every user purchase intent.
     */
    private val purchaseUpdateListener = PurchasesUpdatedListener { billingResult: BillingResult, purchases: List<Purchase>? ->
        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            Log.d(this, "purchaseUpdateListener OK")
            for (purchase in purchases) {
                handlePurchase(purchase)
            }
        } else if (billingResult.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
            // Handle an error caused by a user cancelling the purchase flow.
            Log.d(this, "purchaseUpdateListener USER_CANCELLED")
        } else if (billingResult.responseCode == BillingClient.BillingResponseCode.BILLING_UNAVAILABLE) {
            // Billing API version is not supported for the type requested.
            Log.d(this, "purchaseUpdateListener BILLING_UNAVAILABLE")
        } else if (billingResult.responseCode == BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE) {
            // Network connection is down.
            Log.d(this, "purchaseUpdateListener SERVICE_UNAVAILABLE")
        } else {
            // Handle any other error codes.
            Log.d(this, "purchaseUpdateListener ERROR - message: " + billingResult.debugMessage)
        }
    }

    private val billingClientStateListener: BillingClientStateListener = object : BillingClientStateListener {
        override fun onBillingSetupFinished(billingResult: BillingResult) {
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                Log.d(this, "onBillingSetupFinished OK")
                listener?.onBillingConnectionReady()
            } else {
                listener?.onBillingConnectionError("Error connecting to Play Store.")
            }
        }

        override fun onBillingServiceDisconnected() {
            Log.d(this, "onBillingServiceDisconnected")
            // Try to restart the connection on the next request to
            // Google Play by calling the startConnection() method.
            listener?.onBillingConnectionError("Error connecting to Play Store.")
        }
    }

    private val billingClient: BillingClient = BillingClient.newBuilder(context)
            .setListener(purchaseUpdateListener)
            .enablePendingPurchases()
            .build()

    override fun startBillingConnection(listener: SubscriptionsListener?) {
        this.listener = listener
        billingClient.startConnection(billingClientStateListener)
    }

    override fun syncSubscriptionState() {
        scope.launch(Dispatchers.Default) {
            if (hasActiveSubscription()) syncActiveSubscription()
            else syncAvailableSubscription()
        }
    }

    override fun purchaseSubscription(activity: Activity, skuDetails: SkuDetails) {
        Log.d(this, "launchBillingFlow for sku: ${skuDetails.sku}")
        val billingFlowParams = BillingFlowParams.newBuilder()
                .setSkuDetails(skuDetails)
                .build()
        billingClient.launchBillingFlow(activity, billingFlowParams)
    }

    override suspend fun syncActiveSubscription() = scope.launch(Dispatchers.Default) {
        val hasNewsBlurSubscription = PrefsUtils.getIsPremium(context)
        val activePlayStoreSubscription = getActiveSubscriptionAsync().await()

        if (hasNewsBlurSubscription || activePlayStoreSubscription != null) {
            listener?.let {
                val renewalString: String? = getRenewalMessage(activePlayStoreSubscription)
                withContext(Dispatchers.Main) {
                    it.onActiveSubscription(renewalString)
                }
            }
        }

        if (!hasNewsBlurSubscription && activePlayStoreSubscription != null) {
            saveReceipt(activePlayStoreSubscription)
        }
    }

    override suspend fun hasActiveSubscription(): Boolean =
            PrefsUtils.getIsPremium(context) || getActiveSubscriptionAsync().await() != null

    override fun saveReceipt(purchase: Purchase) {
        Log.d(this, "saveReceipt: ${purchase.orderId}")
        val hiltEntryPoint = EntryPointAccessors
                .fromApplication(context.applicationContext, SubscriptionManagerEntryPoint::class.java)
        scope.executeAsyncTask(
                doInBackground = {
                    hiltEntryPoint.apiManager().saveReceipt(purchase.orderId, purchase.skus.first())
                },
                onPostExecute = {
                    if (!it.isError) {
                        NBSyncService.forceFeedsFolders()
                        FeedUtils.triggerSync(context)
                    }
                }
        )
    }

    private suspend fun syncAvailableSubscription() = scope.launch(Dispatchers.Default) {
        val skuDetails = getAvailableSubscriptionAsync().await()
        withContext(Dispatchers.Main) {
            skuDetails?.let {
                Log.d(this, it.toString())
                listener?.onAvailableSubscription(it)
            } ?: listener?.onBillingConnectionError()
        }
    }

    private fun getAvailableSubscriptionAsync(): Deferred<SkuDetails?> {
        val deferred = CompletableDeferred<SkuDetails?>()
        val params = SkuDetailsParams.newBuilder().apply {
            // add subscription SKUs from Play Store
            setSkusList(listOf(AppConstants.PREMIUM_SKU))
            setType(BillingClient.SkuType.SUBS)
        }.build()

        billingClient.querySkuDetailsAsync(params) { _: BillingResult?, skuDetailsList: List<SkuDetails>? ->
            Log.d(this, "SkuDetailsResponse ${skuDetailsList.toString()}")
            skuDetailsList?.let {
                // Currently interested only in the premium yearly News Blur subscription.
                val skuDetails = it.find { skuDetails ->
                    skuDetails.sku == AppConstants.PREMIUM_SKU
                }

                Log.d(this, skuDetails.toString())
                deferred.complete(skuDetails)
            } ?: deferred.complete(null)
        }

        return deferred
    }

    private fun getActiveSubscriptionAsync(): Deferred<Purchase?> {
        val deferred = CompletableDeferred<Purchase?>()
        billingClient.queryPurchasesAsync(BillingClient.SkuType.SUBS) { _, purchases ->
            val purchase = purchases.find { purchase -> purchase.skus.contains(AppConstants.PREMIUM_SKU) }
            deferred.complete(purchase)
        }

        return deferred
    }

    private fun handlePurchase(purchase: Purchase) {
        Log.d(this, "handlePurchase: ${purchase.orderId}")
        if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED && purchase.isAcknowledged) {
            scope.launch(Dispatchers.Default) {
                syncActiveSubscription()
            }
        } else if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED && !purchase.isAcknowledged) {
            // need to acknowledge first time sub otherwise it will void
            Log.d(this, "acknowledge purchase: ${purchase.orderId}")
            AcknowledgePurchaseParams.newBuilder()
                    .setPurchaseToken(purchase.purchaseToken)
                    .build()
                    .also {
                        billingClient.acknowledgePurchase(it, acknowledgePurchaseListener)
                    }
        }
    }

    /**
     * Generate subscription renewal message.
     */
    private fun getRenewalMessage(purchase: Purchase?): String? {
        val expirationTimeMs = PrefsUtils.getPremiumExpire(context)
        return when {
            // lifetime subscription
            expirationTimeMs == 0L -> {
                context.getString(R.string.premium_subscription_no_expiration)
            }
            expirationTimeMs > 0 -> {
                // date constructor expects ms
                val expirationDate = Date(expirationTimeMs * 1000)
                val dateFormat: DateFormat = SimpleDateFormat("EEE, MMMM d, yyyy", Locale.getDefault())
                dateFormat.timeZone = TimeZone.getDefault()
                if (purchase != null && !purchase.isAutoRenewing) {
                    context.getString(R.string.premium_subscription_expiration, dateFormat.format(expirationDate))
                } else {
                    context.getString(R.string.premium_subscription_renewal, dateFormat.format(expirationDate))
                }
            }
            else -> null
        }
    }
}