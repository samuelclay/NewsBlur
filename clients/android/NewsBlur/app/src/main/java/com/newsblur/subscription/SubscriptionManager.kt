package com.newsblur.subscription

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.*
import com.newsblur.R
import com.newsblur.network.APIManager
import com.newsblur.service.NBSyncService
import com.newsblur.util.*
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.*
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
     * @param productDetails Product details for the intended purchases.
     * @param offerDetails Offer details for subscription.
     */
    fun purchaseSubscription(activity: Activity, productDetails: ProductDetails, offerDetails: ProductDetails.SubscriptionOfferDetails)

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

    fun onActiveSubscription(renewalMessage: String?, isPremium: Boolean, isArchive: Boolean) {}

    fun onAvailableSubscriptions(productDetails: List<ProductDetails>) {}

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
            val productDetails = getAvailableSubscriptionAsync().await()
            withContext(Dispatchers.Main) {
                if (productDetails.isNotEmpty()) {
                    listener?.onAvailableSubscriptions(productDetails)
                } else {
                    listener?.onBillingConnectionError()
                }
            }

            syncActiveSubscription()
        }
    }

    override fun purchaseSubscription(activity: Activity, productDetails: ProductDetails, offerDetails: ProductDetails.SubscriptionOfferDetails) {
        Log.d(this, "launchBillingFlow for productId: ${productDetails.productId}")
        scope.launch(Dispatchers.Default) {
            val productDetailsParamsList = listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                            .setProductDetails(productDetails)
                            .setOfferToken(offerDetails.offerToken)
                            .build()
            )
            val billingFlowParamsBuilder = BillingFlowParams.newBuilder()
                    .setProductDetailsParamsList(productDetailsParamsList)

            // check if there is an active subscription
            val activeSubscription = getActiveSubscriptionAsync().await()
            activeSubscription?.let {
                // check if it's gonna be a subscription upgrade or downgrade
                // this should be the case if there is an active subscription
                if (it.products.firstOrNull() != productDetails.productId) {
                    billingFlowParamsBuilder.setSubscriptionUpdateParams(
                            BillingFlowParams.SubscriptionUpdateParams.newBuilder()
                                    .setOldPurchaseToken(it.purchaseToken)
                                    .setReplaceProrationMode(BillingFlowParams.ProrationMode.IMMEDIATE_AND_CHARGE_PRORATED_PRICE)
                                    .build()
                    )
                }
            }
            withContext(Dispatchers.Main) {
                billingClient.launchBillingFlow(activity, billingFlowParamsBuilder.build())
            }
        }
    }

    override suspend fun syncActiveSubscription() = scope.launch(Dispatchers.Default) {
        val isPremium = PrefsUtils.getIsPremium(context)
        val isArchive = PrefsUtils.getIsArchive(context)
        val activePlayStoreSubscription = getActiveSubscriptionAsync().await()

        if (isPremium || isArchive || activePlayStoreSubscription != null) {
            listener?.let {
                val renewalString: String? = getRenewalMessage(activePlayStoreSubscription)
                withContext(Dispatchers.Main) {
                    it.onActiveSubscription(renewalString, isPremium, isArchive)
                }
            }
        }

        activePlayStoreSubscription?.let { purchase ->
            if (purchase.isPremiumSub() && !isPremium) {
                saveReceipt(purchase)
            } else if (purchase.isArchiveSub() && !isArchive) {
                saveReceipt(purchase)
            }
        }
    }

    override suspend fun hasActiveSubscription(): Boolean =
            PrefsUtils.hasSubscription(context) ||
                    getActiveSubscriptionAsync().await() != null

    override fun saveReceipt(purchase: Purchase) {
        Log.d(this, "saveReceipt: ${purchase.orderId}")
        val hiltEntryPoint = EntryPointAccessors
                .fromApplication(context.applicationContext, SubscriptionManagerEntryPoint::class.java)
        scope.executeAsyncTask(
                doInBackground = {
                    hiltEntryPoint.apiManager().saveReceipt(purchase.orderId, purchase.products.first())
                },
                onPostExecute = {
                    if (!it.isError) {
                        NBSyncService.forceFeedsFolders()
                        FeedUtils.triggerSync(context)
                    }
                }
        )
    }

    private fun getAvailableSubscriptionAsync(): Deferred<List<ProductDetails>> {
        val deferred = CompletableDeferred<List<ProductDetails>>()
        val params = QueryProductDetailsParams.newBuilder().apply {
            // add subscription SKUs from Play Store
            setProductList(listOf(
                    QueryProductDetailsParams.Product.newBuilder()
                            .setProductId(AppConstants.PREMIUM_SUB_ID)
                            .setProductType(BillingClient.ProductType.SUBS)
                            .build(),
                    QueryProductDetailsParams.Product.newBuilder()
                            .setProductId(AppConstants.PREMIUM_ARCHIVE_SUB_ID)
                            .setProductType(BillingClient.ProductType.SUBS)
                            .build(),
            ))
        }.build()

        billingClient.queryProductDetailsAsync(params) { _: BillingResult?, productDetailsList: List<ProductDetails> ->
            Log.d(this, "ProductDetailsResponse $productDetailsList")
            val productDetails = productDetailsList.filter {
                it.productId == AppConstants.PREMIUM_SUB_ID ||
                        it.productId == AppConstants.PREMIUM_ARCHIVE_SUB_ID
            }
            deferred.complete(productDetails)
        }

        return deferred
    }

    private fun getActiveSubscriptionAsync(): Deferred<Purchase?> {
        val deferred = CompletableDeferred<Purchase?>()
        billingClient.queryPurchasesAsync(
                QueryPurchasesParams.newBuilder()
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()) { _, purchasesList ->
            val purchases = purchasesList.filter { purchase ->
                purchase.products.contains(AppConstants.PREMIUM_SUB_ID) ||
                        purchase.products.contains(AppConstants.PREMIUM_ARCHIVE_SUB_ID)
            }
            deferred.complete(purchases.firstOrNull())
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
        val expirationTimeMs = PrefsUtils.getSubscriptionExpire(context)
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

    private fun Purchase.isPremiumSub() = this.products.firstOrNull() == AppConstants.PREMIUM_SUB_ID

    private fun Purchase.isArchiveSub() = this.products.firstOrNull() == AppConstants.PREMIUM_ARCHIVE_SUB_ID
}