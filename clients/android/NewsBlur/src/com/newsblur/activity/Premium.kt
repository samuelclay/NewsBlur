package com.newsblur.activity

import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.os.Bundle
import android.text.TextUtils
import android.text.util.Linkify
import android.view.View
import android.widget.TextView
import androidx.lifecycle.lifecycleScope
import com.android.billingclient.api.*
import com.newsblur.R
import com.newsblur.databinding.ActivityPremiumBinding
import com.newsblur.network.APIManager
import com.newsblur.service.NBSyncService
import com.newsblur.util.*
import nl.dionsegijn.konfetti.emitters.StreamEmitter
import nl.dionsegijn.konfetti.models.Shape.Circle
import nl.dionsegijn.konfetti.models.Shape.Square
import nl.dionsegijn.konfetti.models.Size
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.*

class Premium : NbActivity() {

    private lateinit var binding: ActivityPremiumBinding
    private lateinit var billingClient: BillingClient

    private var subscriptionDetails: SkuDetails? = null
    private var purchasedSubscription: Purchase? = null

    private val acknowledgePurchaseResponseListener = AcknowledgePurchaseResponseListener { billingResult: BillingResult ->
        when (billingResult.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                Log.d(this@Premium.localClassName, "acknowledgePurchaseResponseListener OK")
                verifyUserSubscriptionStatus()
            }
            BillingClient.BillingResponseCode.BILLING_UNAVAILABLE -> {
                // Billing API version is not supported for the type requested.
                Log.d(this@Premium.localClassName, "acknowledgePurchaseResponseListener BILLING_UNAVAILABLE")
            }
            BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE -> {
                // Network connection is down.
                Log.d(this@Premium.localClassName, "acknowledgePurchaseResponseListener SERVICE_UNAVAILABLE")
            }
            else -> {
                // Handle any other error codes.
                Log.d(this@Premium.localClassName, "acknowledgePurchaseResponseListener ERROR - message: " + billingResult.debugMessage)
            }
        }
    }
    private val purchaseUpdateListener = PurchasesUpdatedListener { billingResult: BillingResult, purchases: List<Purchase>? ->
        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            Log.d(this@Premium.localClassName, "purchaseUpdateListener OK")
            for (purchase in purchases) {
                handlePurchase(purchase)
            }
        } else if (billingResult.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
            // Handle an error caused by a user cancelling the purchase flow.
            Log.d(this@Premium.localClassName, "purchaseUpdateListener USER_CANCELLED")
        } else if (billingResult.responseCode == BillingClient.BillingResponseCode.BILLING_UNAVAILABLE) {
            // Billing API version is not supported for the type requested.
            Log.d(this@Premium.localClassName, "purchaseUpdateListener BILLING_UNAVAILABLE")
        } else if (billingResult.responseCode == BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE) {
            // Network connection is down.
            Log.d(this@Premium.localClassName, "purchaseUpdateListener SERVICE_UNAVAILABLE")
        } else {
            // Handle any other error codes.
            Log.d(this@Premium.localClassName, "purchaseUpdateListener ERROR - message: " + billingResult.debugMessage)
        }
    }
    private val billingClientStateListener: BillingClientStateListener = object : BillingClientStateListener {
        override fun onBillingSetupFinished(billingResult: BillingResult) {
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                // The BillingClient is ready. You can query purchases here.
                Log.d(this@Premium.localClassName, "onBillingSetupFinished OK")
                retrievePlayStoreSubscriptions()
                verifyUserSubscriptionStatus()
            } else {
                showSubscriptionDetailsError()
            }
        }

        override fun onBillingServiceDisconnected() {
            Log.d(this@Premium.localClassName, "onBillingServiceDisconnected")
            // Try to restart the connection on the next request to
            // Google Play by calling the startConnection() method.
            showSubscriptionDetailsError()
        }
    }

    override fun onCreate(bundle: Bundle?) {
        super.onCreate(bundle)
        binding = ActivityPremiumBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setupUI()
        setupBillingClient()
    }

    private fun setupUI() {
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.premium_toolbar_title), true)

        // linkify before setting the string resource
        BetterLinkMovementMethod.linkify(Linkify.WEB_URLS, binding.textPolicies)
                .setOnLinkClickListener { _: TextView?, url: String? ->
                    UIUtils.handleUri(this@Premium, Uri.parse(url))
                    true
                }
        binding.textPolicies.text = UIUtils.fromHtml(getString(R.string.premium_policies))
        binding.textSubTitle.paintFlags = binding.textSubTitle.paintFlags or Paint.UNDERLINE_TEXT_FLAG
        FeedUtils.iconLoader!!.displayImage(AppConstants.SHILOH_PHOTO_URL, binding.imgShiloh)
    }

    private fun setupBillingClient() {
        billingClient = BillingClient.newBuilder(this)
                .setListener(purchaseUpdateListener)
                .enablePendingPurchases()
                .build()
        billingClient.startConnection(billingClientStateListener)
    }

    private fun verifyUserSubscriptionStatus() {
        val hasNewsBlurSubscription = PrefsUtils.getIsPremium(this)
        var playStoreSubscription: Purchase? = null
        val result = billingClient.queryPurchases(BillingClient.SkuType.SUBS)
        if (result.purchasesList != null) {
            for (purchase in result.purchasesList!!) {
                if (purchase.sku == AppConstants.PREMIUM_SKU) {
                    playStoreSubscription = purchase
                }
            }
        }
        if (hasNewsBlurSubscription || playStoreSubscription != null) {
            binding.containerGoingPremium.visibility = View.GONE
            binding.containerGonePremium.visibility = View.VISIBLE
            val expirationTimeMs = PrefsUtils.getPremiumExpire(this)
            var renewalString: String? = null
            if (expirationTimeMs == 0L) {
                renewalString = getString(R.string.premium_subscription_no_expiration)
            } else if (expirationTimeMs > 0) {
                // date constructor expects ms
                val expirationDate = Date(expirationTimeMs * 1000)
                val dateFormat: DateFormat = SimpleDateFormat("EEE, MMMM d, yyyy", Locale.getDefault())
                dateFormat.timeZone = TimeZone.getDefault()
                renewalString = getString(R.string.premium_subscription_renewal, dateFormat.format(expirationDate))
                if (playStoreSubscription != null && !playStoreSubscription.isAutoRenewing) {
                    renewalString = getString(R.string.premium_subscription_expiration, dateFormat.format(expirationDate))
                }
            }
            if (!TextUtils.isEmpty(renewalString)) {
                binding.textSubscriptionRenewal.text = renewalString
                binding.textSubscriptionRenewal.visibility = View.VISIBLE
            }
            showConfetti()
        }
        if (!hasNewsBlurSubscription && playStoreSubscription != null) {
            purchasedSubscription = playStoreSubscription
            notifyNewsBlurOfSubscription()
        }
    }

    private fun retrievePlayStoreSubscriptions() {
        val skuList: MutableList<String> = ArrayList(1)
        // add sub SKUs from Play Store
        skuList.add(AppConstants.PREMIUM_SKU)
        val params = SkuDetailsParams.newBuilder()
        params.setSkusList(skuList).setType(BillingClient.SkuType.SUBS)
        billingClient.querySkuDetailsAsync(params.build()) { _: BillingResult?, skuDetailsList: List<SkuDetails>? ->
            Log.d(this@Premium.localClassName, "SkuDetailsResponse")
            processSkuDetailsList(skuDetailsList)
        }
    }

    private fun processSkuDetailsList(skuDetailsList: List<SkuDetails>?) {
        if (skuDetailsList != null) {
            for (skuDetails in skuDetailsList) {
                if (skuDetails.sku == AppConstants.PREMIUM_SKU) {
                    Log.d(this@Premium.localClassName, "Sku detail: " + skuDetails.title + " | " + skuDetails.description + " | " + skuDetails.price + " | " + skuDetails.sku)
                    subscriptionDetails = skuDetails
                }
            }
        }
        if (subscriptionDetails != null) {
            showSubscriptionDetails()
        } else {
            showSubscriptionDetailsError()
        }
    }

    private fun showSubscriptionDetailsError() {
        binding.textLoading.setText(R.string.premium_subscription_details_error)
        binding.textLoading.visibility = View.VISIBLE
        binding.containerSub.visibility = View.GONE
    }

    private fun showSubscriptionDetails() {
        val price = (subscriptionDetails!!.priceAmountMicros / 1000f / 1000f).toDouble()
        val currency = Currency.getInstance(subscriptionDetails!!.priceCurrencyCode)
        val currencySymbol = currency.getSymbol(Locale.getDefault())
        val pricingText = StringBuilder()
        pricingText.append(subscriptionDetails!!.price)
        pricingText.append(" per year (")
        pricingText.append(currencySymbol)
        pricingText.append(String.format(Locale.getDefault(), "%.2f", price / 12))
        pricingText.append("/month)")
        binding.textSubTitle.text = subscriptionDetails!!.title
        binding.textSubPrice.text = pricingText
        binding.textLoading.visibility = View.GONE
        binding.containerSub.visibility = View.VISIBLE
        binding.containerSub.setOnClickListener { launchBillingFlow(subscriptionDetails!!) }
    }

    private fun launchBillingFlow(skuDetails: SkuDetails) {
        Log.d(this@Premium.localClassName, "launchBillingFlow for sku: " + skuDetails.sku)
        val billingFlowParams = BillingFlowParams.newBuilder()
                .setSkuDetails(skuDetails)
                .build()
        billingClient.launchBillingFlow(this, billingFlowParams)
    }

    private fun handlePurchase(purchase: Purchase) {
        Log.d(this@Premium.localClassName, "handlePurchase: " + purchase.orderId)
        purchasedSubscription = purchase
        if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED && purchase.isAcknowledged) {
            verifyUserSubscriptionStatus()
        } else if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED && !purchase.isAcknowledged) {
            // need to acknowledge first time sub otherwise it will void
            Log.d(this@Premium.localClassName, "acknowledge purchase: " + purchase.orderId)
            val acknowledgePurchaseParams = AcknowledgePurchaseParams.newBuilder()
                    .setPurchaseToken(purchase.purchaseToken)
                    .build()
            billingClient.acknowledgePurchase(acknowledgePurchaseParams, acknowledgePurchaseResponseListener)
        }
    }

    private fun showConfetti() {
        binding.konfetti.build()
                .addColors(Color.YELLOW, Color.GREEN, Color.MAGENTA, Color.BLUE, Color.CYAN, Color.RED)
                .setDirection(90.0)
                .setFadeOutEnabled(true)
                .setTimeToLive(1000L)
                .addShapes(Square, Circle)
                .addSizes(Size(10, 5f))
                .setPosition(0f, binding.konfetti.width + 0f, -50f, -20f)
                .streamFor(100, StreamEmitter.INDEFINITE)
    }

    private fun notifyNewsBlurOfSubscription() {
        if (purchasedSubscription != null) {
            val apiManager = APIManager(this)
            lifecycleScope.executeAsyncTask(
                    doInBackground = {
                        apiManager.saveReceipt(purchasedSubscription!!.orderId, purchasedSubscription!!.sku)
                    },
                    onPostExecute = {
                        if (!it.isError) {
                            NBSyncService.forceFeedsFolders()
                            triggerSync()
                        }
                        finish()
                    }
            )
        }
    }
}