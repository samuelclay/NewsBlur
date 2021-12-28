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
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.*

interface SubscriptionManager {

    /**
     * Open connection to Play Store to retrieve
     * purchases and subscriptions.
     */
    fun startBillingConnection()

    /**
     * Generated subscription state by retrieve all available subscriptions
     * and checking whether the user has an active subscription.
     *
     * Subscriptions are configured via the Play Store console.
     */
    fun getSubscriptionState()

    /**
     * Launch the billing flow overlay for a specific subscription.
     * @param activity Activity on which the billing overlay will be displayed.
     * @param skuDetails Subscription details for the intended purchases.
     */
    fun purchaseSubscription(activity: Activity, skuDetails: SkuDetails)

    /**
     * Sync subscription state between NewsBlur and Play Store.
     */
    fun syncActiveSubscription()

    fun hasActiveSubscription(): Boolean
}

interface SubscriptionsListener {

    fun onActiveSubscription(renewalMessage: String?)

    fun onAvailableSubscription(skuDetails: SkuDetails)

    fun onBillingConnectionReady()

    fun onBillingConnectionError(message: String? = null)
}

class SubscriptionManagerImpl(
        private val context: Context,
        private val listener: SubscriptionsListener
) : SubscriptionManager {

    private val acknowledgePurchaseListener = AcknowledgePurchaseResponseListener { billingResult: BillingResult ->
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                Log.d(this, "acknowledgePurchaseResponseListener OK")
                syncActiveSubscription()
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
                listener.onBillingConnectionReady()
            } else {
                listener.onBillingConnectionError("Error connecting to Play Store.")
            }
        }

        override fun onBillingServiceDisconnected() {
            Log.d(this, "onBillingServiceDisconnected")
            // Try to restart the connection on the next request to
            // Google Play by calling the startConnection() method.
            listener.onBillingConnectionError("Error connecting to Play Store.")
        }
    }

    private val billingClient: BillingClient = BillingClient.newBuilder(context)
            .setListener(purchaseUpdateListener)
            .enablePendingPurchases()
            .build()

    override fun startBillingConnection() {
        billingClient.startConnection(billingClientStateListener)
    }

    override fun getSubscriptionState() =
            if (hasActiveSubscription()) syncActiveSubscription()
            else syncAvailableSubscription()

    override fun purchaseSubscription(activity: Activity, skuDetails: SkuDetails) {
        Log.d(this, "launchBillingFlow for sku: ${skuDetails.sku}")
        val billingFlowParams = BillingFlowParams.newBuilder()
                .setSkuDetails(skuDetails)
                .build()
        billingClient.launchBillingFlow(activity, billingFlowParams)
    }

    override fun syncActiveSubscription() {
        val hasNewsBlurSubscription = PrefsUtils.getIsPremium(context)
        val activePlayStoreSubscription = getActivePlayStoreSubscription()

        if (hasNewsBlurSubscription || activePlayStoreSubscription != null) {
            val renewalString: String? = getRenewalMessage(activePlayStoreSubscription)
            listener.onActiveSubscription(renewalString)
        }

        if (!hasNewsBlurSubscription && activePlayStoreSubscription != null) {
            saveSubscriptionReceipt(activePlayStoreSubscription)
        }
    }

    override fun hasActiveSubscription(): Boolean =
            PrefsUtils.getIsPremium(context) || getActivePlayStoreSubscription() != null

    private fun getActivePlayStoreSubscription(): Purchase? {
        val result = billingClient.queryPurchases(BillingClient.SkuType.SUBS)
        return result.purchasesList?.let {
            it.find { purchase -> purchase.sku == AppConstants.PREMIUM_SKU }
        }
    }

    private fun syncAvailableSubscription() {
        val params = SkuDetailsParams.newBuilder().apply {
            // add subscription SKUs from Play Store
            setSkusList(listOf(AppConstants.PREMIUM_SKU))
            setType(BillingClient.SkuType.SUBS)
        }.build()

        billingClient.querySkuDetailsAsync(params) { _: BillingResult?, skuDetailsList: List<SkuDetails>? ->
            Log.d(this, "SkuDetailsResponse ${skuDetailsList.toString()}")
            skuDetailsList?.let {
                // Currently interested only in the premium yearly News Blur subscription.
                val premiumSubscription = it.find { skuDetails ->
                    skuDetails.sku == AppConstants.PREMIUM_SKU
                }

                premiumSubscription?.let { skuDetail ->
                    Log.d(this, skuDetail.toString())
                    listener.onAvailableSubscription(skuDetail)
                } ?: listener.onBillingConnectionError()
            }
        }
    }

    private fun handlePurchase(purchase: Purchase) {
        Log.d(this, "handlePurchase: ${purchase.orderId}")
        if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED && purchase.isAcknowledged) {
            syncActiveSubscription()
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
     * Notify backend of active Play Store subscription.
     */
    private fun saveSubscriptionReceipt(purchase: Purchase) {
        val apiManager = APIManager(context)
        NBScope.executeAsyncTask(
                doInBackground = {
                    apiManager.saveReceipt(purchase.orderId, purchase.sku)
                },
                onPostExecute = {
                    if (!it.isError) {
                        NBSyncService.forceFeedsFolders()
                        FeedUtils.triggerSync(context)
                    }
                }
        )
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