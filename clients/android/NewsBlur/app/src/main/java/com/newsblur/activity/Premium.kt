package com.newsblur.activity

import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.os.Bundle
import android.text.util.Linkify
import android.view.View
import android.widget.TextView
import androidx.lifecycle.lifecycleScope
import com.android.billingclient.api.*
import com.newsblur.R
import com.newsblur.databinding.ActivityPremiumBinding
import com.newsblur.di.IconLoader
import com.newsblur.subscription.SubscriptionManager
import com.newsblur.subscription.SubscriptionManagerImpl
import com.newsblur.subscription.SubscriptionsListener
import com.newsblur.util.*
import dagger.hilt.android.AndroidEntryPoint
import nl.dionsegijn.konfetti.emitters.StreamEmitter
import nl.dionsegijn.konfetti.models.Shape.Circle
import nl.dionsegijn.konfetti.models.Shape.Square
import nl.dionsegijn.konfetti.models.Size
import java.util.*
import javax.inject.Inject

@AndroidEntryPoint
class Premium : NbActivity() {

    @IconLoader
    @Inject
    lateinit var iconLoader: ImageLoader

    private lateinit var binding: ActivityPremiumBinding
    private lateinit var subscriptionManager: SubscriptionManager

    private val subscriptionManagerListener = object : SubscriptionsListener {

        override fun onActiveSubscription(renewalMessage: String?) {
            showActiveSubscriptionDetails(renewalMessage)
        }

        override fun onAvailableSubscription(skuDetails: SkuDetails) {
            showAvailableSubscriptionDetails(skuDetails)
        }

        override fun onBillingConnectionReady() {
            subscriptionManager.syncSubscriptionState()
        }

        override fun onBillingConnectionError(message: String?) {
            showSubscriptionDetailsError(message)
        }
    }

    override fun onCreate(bundle: Bundle?) {
        super.onCreate(bundle)
        binding = ActivityPremiumBinding.inflate(layoutInflater)
        setContentView(binding.root)
        setupUI()
        setupBilling()
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
        iconLoader.displayImage(AppConstants.SHILOH_PHOTO_URL, binding.imgShiloh)
    }

    private fun setupBilling() {
        subscriptionManager = SubscriptionManagerImpl(this, lifecycleScope)
        subscriptionManager.startBillingConnection(subscriptionManagerListener)
    }

    private fun showSubscriptionDetailsError(message: String?) {
        binding.textLoading.text = message ?: getString(R.string.premium_subscription_details_error)
        binding.textLoading.visibility = View.VISIBLE
        binding.containerSub.visibility = View.GONE
    }

    private fun showAvailableSubscriptionDetails(skuDetails: SkuDetails) {
        val price = (skuDetails.priceAmountMicros / 1000f / 1000f).toDouble()
        val currency = Currency.getInstance(skuDetails.priceCurrencyCode)
        val currencySymbol = currency.getSymbol(Locale.getDefault())
        val pricingText = StringBuilder()
        pricingText.append(skuDetails.price)
        pricingText.append(" per year (")
        pricingText.append(currencySymbol)
        pricingText.append(String.format(Locale.getDefault(), "%.2f", price / 12))
        pricingText.append("/month)")
        binding.textSubTitle.text = skuDetails.title
        binding.textSubPrice.text = pricingText
        binding.textLoading.visibility = View.GONE
        binding.containerSub.visibility = View.VISIBLE
        binding.containerSub.setOnClickListener {
            subscriptionManager.purchaseSubscription(this, skuDetails)
        }
    }

    private fun showActiveSubscriptionDetails(renewalMessage: String?) {
        binding.containerGoingPremium.visibility = View.GONE
        binding.containerGonePremium.visibility = View.VISIBLE

        if (!renewalMessage.isNullOrEmpty()) {
            binding.textSubscriptionRenewal.text = renewalMessage
            binding.textSubscriptionRenewal.visibility = View.VISIBLE
        }

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
}