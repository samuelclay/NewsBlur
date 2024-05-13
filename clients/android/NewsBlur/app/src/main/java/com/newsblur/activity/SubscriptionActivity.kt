package com.newsblur.activity

import android.net.Uri
import android.os.Bundle
import android.text.util.Linkify
import android.view.View
import android.widget.TextView
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import com.android.billingclient.api.ProductDetails
import com.newsblur.R
import com.newsblur.databinding.ActivitySubscriptionBinding
import com.newsblur.databinding.ViewArchiveSubscriptionBinding
import com.newsblur.databinding.ViewPremiumSubscriptionBinding
import com.newsblur.di.IconLoader
import com.newsblur.subscription.SubscriptionManager
import com.newsblur.subscription.SubscriptionManagerImpl
import com.newsblur.subscription.SubscriptionsListener
import com.newsblur.util.*
import dagger.hilt.android.AndroidEntryPoint
import java.util.*
import javax.inject.Inject

/**
 * - no subscription - all both load and both can be clicked DONE
 * - no subscription - go premium and verify that it applied, screen is showing state
 * - no subscription - go archive and verify that it applied, screen is showing state
 * - premium subscription - can upgrade to archive. upgrade and see difference and state
 * - archive subscription - can downgrade to premium?. downgrade and see difference and state
 * - valid subscription but no NB is subscribed. Check is it will send receipt
 */
@AndroidEntryPoint
class SubscriptionActivity : NbActivity() {

    @IconLoader
    @Inject
    lateinit var iconLoader: ImageLoader

    private lateinit var binding: ActivitySubscriptionBinding
    private lateinit var bindingPremium: ViewPremiumSubscriptionBinding
    private lateinit var bindingArchive: ViewArchiveSubscriptionBinding
    private lateinit var subscriptionManager: SubscriptionManager

    private val subscriptionManagerListener = object : SubscriptionsListener {

        override fun onActiveSubscription(renewalMessage: String?, isPremium: Boolean, isArchive: Boolean) {
            showActiveSubscriptionDetails(renewalMessage, isPremium, isArchive)
        }

        override fun onAvailableSubscriptions(productDetails: List<ProductDetails>) {
            showAvailableSubscriptionDetails(productDetails)
        }

        override fun onBillingConnectionReady() {
            subscriptionManager.syncSubscriptionState()
        }

        override fun onBillingConnectionError(message: String?) {
            showSubscriptionDetailsError(message)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySubscriptionBinding.inflate(layoutInflater)
        bindingPremium = ViewPremiumSubscriptionBinding.bind(binding.containerPremiumSubscription.root)
        bindingArchive = ViewArchiveSubscriptionBinding.bind(binding.containerArchiveSubscription.root)
        setContentView(binding.root)
        setupUI()
        setupBilling()
    }

    private fun setupUI() {
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.subscription_toolbar_title), true)

        // linkify before setting the string resource
        BetterLinkMovementMethod.linkify(Linkify.WEB_URLS, binding.textPolicies)
                .setOnLinkClickListener { _: TextView?, url: String? ->
                    UIUtils.handleUri(this@SubscriptionActivity, Uri.parse(url))
                    true
                }
        binding.textPolicies.text = UIUtils.fromHtml(getString(R.string.premium_policies))
        iconLoader.displayImage(AppConstants.LYRIC_PHOTO_URL, bindingPremium.imgShiloh)
    }

    private fun setupBilling() {
        subscriptionManager = SubscriptionManagerImpl(this, lifecycleScope)
        subscriptionManager.startBillingConnection(subscriptionManagerListener)
    }

    private fun showSubscriptionDetailsError(message: String?) {
        message ?: getString(R.string.subscription_details_error).let {
            bindingPremium.textLoading.text = it
            bindingPremium.textLoading.setViewVisible()
            bindingPremium.containerDetails.setViewGone()

            bindingArchive.textLoading.text = it
            bindingArchive.textLoading.setViewVisible()
            bindingArchive.containerDetails.setViewGone()
        }
    }

    private fun showAvailableSubscriptionDetails(productDetails: List<ProductDetails>) {
        productDetails.find { it.productId == AppConstants.PREMIUM_SUB_ID }?.let {
            showPremiumSubscription(it)
        } ?: hidePremiumSubscription()
        // TODO enabled once upgrades and downgrades are supported
        /*productDetails.find { it.productId == AppConstants.PREMIUM_ARCHIVE_SUB_ID }?.let {
            showArchiveSubscription(it)
        } ?: */hideArchiveSubscription()

        if (!bindingPremium.root.isVisible && !bindingArchive.root.isVisible) {
            binding.textNoSubscriptions.setViewVisible()
        }
    }

    private fun showPremiumSubscription(productDetails: ProductDetails) {
        val productOffer = productDetails.subscriptionOfferDetails?.firstOrNull()
        productOffer?.let { offerDetails ->
            val pricingPhase = offerDetails.pricingPhases.pricingPhaseList.firstOrNull()
            pricingPhase?.let { pricing ->
                bindingPremium.textSubPrice.text = extractProductPricing(pricing)
                bindingPremium.textLoading.visibility = View.GONE
                bindingPremium.containerDetails.visibility = View.VISIBLE
                bindingPremium.containerPrice.setOnClickListener {
                    subscriptionManager.purchaseSubscription(this, productDetails, offerDetails)
                }
            }
        } ?: hidePremiumSubscription()
    }

    private fun showArchiveSubscription(productDetails: ProductDetails) {
        val productOffer = productDetails.subscriptionOfferDetails?.firstOrNull()
        productOffer?.let { offerDetails ->
            val pricingPhase = offerDetails.pricingPhases.pricingPhaseList.firstOrNull()
            pricingPhase?.let { pricing ->
                bindingArchive.textSubPrice.text = extractProductPricing(pricing)
                bindingArchive.textLoading.visibility = View.GONE
                bindingArchive.containerDetails.visibility = View.VISIBLE
                bindingArchive.containerPrice.setOnClickListener {
                    subscriptionManager.purchaseSubscription(this, productDetails, offerDetails)
                }
            }
        } ?: hideArchiveSubscription()
    }

    private fun hidePremiumSubscription() {
        bindingPremium.root.visibility = View.GONE
    }

    private fun hideArchiveSubscription() {
        bindingArchive.root.visibility = View.GONE
    }

    private fun showActiveSubscriptionDetails(renewalMessage: String?, isPremium: Boolean, isArchive: Boolean) {
        if (isPremium) {
            bindingPremium.containerPrice.setViewGone()
            bindingPremium.containerActivated.setViewVisible()
            binding.containerSubscribed.setViewVisible()
        } else if (isArchive) {
            bindingArchive.containerPrice.setViewGone()
            bindingArchive.containerActivated.setViewVisible()
            binding.containerSubscribed.setViewVisible()
        }

        if (!renewalMessage.isNullOrEmpty()) {
            binding.textSubscriptionRenewal.text = renewalMessage
            binding.textSubscriptionRenewal.setViewVisible()
        }
    }

    private fun extractProductPricing(pricing: ProductDetails.PricingPhase): String {
        val price = (pricing.priceAmountMicros / 1000f / 1000f).toDouble()
        val currency = Currency.getInstance(pricing.priceCurrencyCode)
        val currencySymbol = currency.getSymbol(Locale.getDefault())
        return StringBuilder().apply {
            append(String.format(Locale.getDefault(), "%.2f", price))
            append(" per year (")
            append(currencySymbol)
            append(String.format(Locale.getDefault(), "%.2f", price / 12))
            append("/month)")
        }.toString()
    }
}