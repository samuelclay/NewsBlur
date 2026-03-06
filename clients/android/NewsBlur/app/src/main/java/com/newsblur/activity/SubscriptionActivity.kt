package com.newsblur.activity

import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.text.util.Linkify
import android.view.LayoutInflater
import android.view.View
import androidx.core.content.ContextCompat
import androidx.core.graphics.ColorUtils
import androidx.core.view.isVisible
import androidx.lifecycle.lifecycleScope
import com.android.billingclient.api.ProductDetails
import com.newsblur.R
import com.newsblur.databinding.ActivitySubscriptionBinding
import com.newsblur.databinding.ViewSubscriptionFeatureRowBinding
import com.newsblur.databinding.ViewSubscriptionTierBinding
import com.newsblur.di.IconLoader
import com.newsblur.network.UserApi
import com.newsblur.subscription.SubscriptionManager
import com.newsblur.subscription.SubscriptionManagerImpl
import com.newsblur.subscription.SubscriptionsListener
import com.newsblur.util.AppConstants
import com.newsblur.util.BetterLinkMovementMethod
import com.newsblur.util.EdgeToEdgeUtil.applyView
import com.newsblur.util.ImageLoader
import com.newsblur.util.PrefConstants.ThemeValue
import com.newsblur.util.UIUtils
import dagger.hilt.android.AndroidEntryPoint
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale
import javax.inject.Inject
import kotlin.math.roundToInt

private data class SubscriptionFeature(
    val titleRes: Int,
    val iconRes: Int,
    val colorRes: Int,
    val upcoming: Boolean = false,
)

private data class SubscriptionTierConfig(
    val headerTitleRes: Int,
    val purchaseTitleRes: Int,
    val headerIconRes: Int,
    val gradientStartRes: Int,
    val gradientEndRes: Int,
    val productId: String,
    val features: List<SubscriptionFeature>,
    val showDogImage: Boolean = false,
)

private data class ActiveSubscriptionState(
    val renewalMessage: String? = null,
    val isPremium: Boolean = false,
    val isArchive: Boolean = false,
    val isPro: Boolean = false,
) {
    val hasAnySubscription: Boolean
        get() = isPremium || isArchive || isPro
}

private data class SubscriptionPalette(
    val background: Int,
    val cardBackground: Int,
    val secondaryBackground: Int,
    val primaryText: Int,
    val secondaryText: Int,
    val border: Int,
)

private sealed class TierUiState {
    data class Active(
        val messageRes: Int,
        val showManage: Boolean,
        val manageProductId: String? = null,
    ) : TierUiState()

    data class Purchase(
        val subtitleRes: Int? = null,
    ) : TierUiState()
}

@AndroidEntryPoint
class SubscriptionActivity : NbActivity() {
    @IconLoader
    @Inject
    lateinit var iconLoader: ImageLoader

    @Inject
    lateinit var userApi: UserApi

    private lateinit var binding: ActivitySubscriptionBinding
    private lateinit var bindingPremium: ViewSubscriptionTierBinding
    private lateinit var bindingArchive: ViewSubscriptionTierBinding
    private lateinit var bindingPro: ViewSubscriptionTierBinding
    private lateinit var subscriptionManager: SubscriptionManager
    private lateinit var palette: SubscriptionPalette

    private var billingErrorMessage: String? = null
    private var availableSubscriptions: Map<String, ProductDetails> = emptyMap()
    private var activeSubscriptionState = ActiveSubscriptionState()

    private val premiumTier =
        SubscriptionTierConfig(
            headerTitleRes = R.string.premium_subscription_header,
            purchaseTitleRes = R.string.premium_subscription_title,
            headerIconRes = R.drawable.ic_star_active,
            gradientStartRes = R.color.premium_gold,
            gradientEndRes = R.color.premium_gold_light,
            productId = AppConstants.PREMIUM_SUB_ID,
            features =
                listOf(
                    SubscriptionFeature(R.string.premium_enable_sites, R.drawable.ic_sheets, R.color.premium_feature_blue),
                    SubscriptionFeature(R.string.premium_sync, R.drawable.ic_bolt, R.color.premium_feature_yellow),
                    SubscriptionFeature(R.string.premium_read_by_folder, R.drawable.ic_magazine, R.color.premium_feature_orange),
                    SubscriptionFeature(R.string.premium_search, R.drawable.ic_search, R.color.premium_feature_purple),
                    SubscriptionFeature(R.string.premium_searchable_tags, R.drawable.ic_tag, R.color.premium_feature_pink),
                    SubscriptionFeature(R.string.premium_privacy_options, R.drawable.ic_privacy, R.color.premium_feature_green),
                    SubscriptionFeature(R.string.premium_custom_rss, R.drawable.ic_rss, R.color.premium_feature_orange),
                    SubscriptionFeature(R.string.premium_text_view, R.drawable.ic_file_edit, R.color.premium_feature_cyan),
                    SubscriptionFeature(R.string.premium_discover_related, R.drawable.ic_world, R.color.premium_feature_teal),
                    SubscriptionFeature(R.string.premium_shiloh, R.drawable.ic_dining, R.color.premium_feature_brown),
                ),
            showDogImage = true,
        )

    private val archiveTier =
        SubscriptionTierConfig(
            headerTitleRes = R.string.archive_subscription_header,
            purchaseTitleRes = R.string.archive_subscription_title,
            headerIconRes = R.drawable.ic_cabinet,
            gradientStartRes = R.color.premium_archive_purple,
            gradientEndRes = R.color.premium_archive_purple_light,
            productId = AppConstants.PREMIUM_ARCHIVE_SUB_ID,
            features =
                listOf(
                    SubscriptionFeature(R.string.archive_everything_premium, R.drawable.ic_burst, R.color.premium_feature_yellow),
                    SubscriptionFeature(R.string.archive_enable_sites, R.drawable.ic_sheets, R.color.premium_feature_blue),
                    SubscriptionFeature(R.string.archive_marked_as_read, R.drawable.ic_read_check, R.color.premium_feature_blue),
                    SubscriptionFeature(R.string.archive_customize_auto_read, android.R.drawable.ic_menu_manage, R.color.premium_feature_green),
                    SubscriptionFeature(R.string.archive_story_searchable_forever, R.drawable.ic_cabinet, R.color.premium_feature_purple),
                    SubscriptionFeature(R.string.archive_back_filled, R.drawable.ic_quad, R.color.premium_feature_teal),
                    SubscriptionFeature(R.string.archive_train_full_text, R.drawable.ic_feed_train, R.color.premium_feature_cyan),
                    SubscriptionFeature(R.string.archive_discover_related, R.drawable.ic_world, R.color.premium_feature_teal),
                    SubscriptionFeature(R.string.archive_export_trained_stories, R.drawable.ic_cloud_upload, R.color.premium_feature_orange),
                    SubscriptionFeature(R.string.archive_stories_unread_forever, R.drawable.ic_calendar, R.color.premium_feature_red),
                    SubscriptionFeature(R.string.archive_ask_ai, android.R.drawable.ic_menu_help, R.color.premium_feature_ai),
                    SubscriptionFeature(R.string.archive_filter_by_date_range, R.drawable.ic_calendar, R.color.premium_feature_pink),
                    SubscriptionFeature(R.string.archive_train_folder, R.drawable.ic_folder, R.color.premium_feature_mint),
                    SubscriptionFeature(R.string.archive_train_globally, R.drawable.ic_world, R.color.premium_feature_indigo),
                ),
        )

    private val proTier =
        SubscriptionTierConfig(
            headerTitleRes = R.string.pro_subscription_header,
            purchaseTitleRes = R.string.pro_subscription_title,
            headerIconRes = R.drawable.ic_burst,
            gradientStartRes = R.color.premium_pro_orange,
            gradientEndRes = R.color.premium_pro_orange_light,
            productId = AppConstants.PREMIUM_PRO_SUB_ID,
            features =
                listOf(
                    SubscriptionFeature(R.string.pro_everything_archive, R.drawable.ic_burst, R.color.premium_feature_yellow),
                    SubscriptionFeature(R.string.pro_enable_sites, R.drawable.ic_sheets, R.color.premium_feature_green),
                    SubscriptionFeature(R.string.pro_all_feeds_fetched, R.drawable.ic_bolt, R.color.premium_feature_orange),
                    SubscriptionFeature(R.string.pro_regex_train, android.R.drawable.ic_menu_edit, R.color.premium_feature_yellow),
                    SubscriptionFeature(R.string.pro_priority_support, android.R.drawable.ic_menu_call, R.color.premium_feature_yellow),
                    SubscriptionFeature(R.string.pro_natural_language_filters, R.drawable.ic_search, R.color.premium_feature_gray, upcoming = true),
                    SubscriptionFeature(R.string.pro_natural_language_search, R.drawable.ic_search_2, R.color.premium_feature_gray, upcoming = true),
                ),
        )

    private val subscriptionManagerListener =
        object : SubscriptionsListener {
            override fun onActiveSubscription(
                renewalMessage: String?,
                isPremium: Boolean,
                isArchive: Boolean,
                isPro: Boolean,
            ) {
                runOnUiThread {
                    activeSubscriptionState =
                        ActiveSubscriptionState(
                            renewalMessage = renewalMessage,
                            isPremium = isPremium,
                            isArchive = isArchive,
                            isPro = isPro,
                        )
                    renderSubscriptionTiers()
                }
            }

            override fun onAvailableSubscriptions(productDetails: List<ProductDetails>) {
                runOnUiThread {
                    billingErrorMessage = null
                    availableSubscriptions = productDetails.associateBy { it.productId }
                    renderSubscriptionTiers()
                }
            }

            override fun onBillingConnectionReady() {
                subscriptionManager.syncSubscriptionState()
            }

            override fun onBillingConnectionError(message: String?) {
                runOnUiThread {
                    billingErrorMessage = message ?: getString(R.string.subscription_details_error)
                    renderSubscriptionTiers()
                }
            }
        }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySubscriptionBinding.inflate(layoutInflater)
        bindingPremium = ViewSubscriptionTierBinding.bind(binding.containerPremiumSubscription.root)
        bindingArchive = ViewSubscriptionTierBinding.bind(binding.containerArchiveSubscription.root)
        bindingPro = ViewSubscriptionTierBinding.bind(binding.containerProSubscription.root)
        palette = buildPalette()
        applyView(binding)
        setupUI()
        renderSubscriptionTiers()
        setupBilling()
    }

    private fun setupUI() {
        UIUtils.setupToolbar(this, R.drawable.logo, getString(R.string.subscription_toolbar_title), true)

        binding.container.setBackgroundColor(palette.background)
        binding.textNoSubscriptions.setTextColor(palette.secondaryText)
        binding.textPolicies.setTextColor(palette.secondaryText)

        BetterLinkMovementMethod
            .linkify(Linkify.WEB_URLS, binding.textPolicies)
            .setOnLinkClickListener { _, url ->
                UIUtils.handleUri(this@SubscriptionActivity, prefsRepo, Uri.parse(url))
                true
            }
        binding.textPolicies.text = UIUtils.fromHtml(getString(R.string.premium_policies))
    }

    private fun setupBilling() {
        subscriptionManager =
            SubscriptionManagerImpl(
                context = this,
                userApi = userApi,
                prefRepository = prefsRepo,
                syncServiceState = syncServiceState,
                scope = lifecycleScope,
            )
        subscriptionManager.startBillingConnection(subscriptionManagerListener)
    }

    private fun renderSubscriptionTiers() {
        renderTier(bindingPremium, premiumTier, premiumUiState())
        renderTier(bindingArchive, archiveTier, archiveUiState())
        renderTier(bindingPro, proTier, proUiState())

        binding.textNoSubscriptions.isVisible =
            billingErrorMessage != null && availableSubscriptions.isEmpty() && !activeSubscriptionState.hasAnySubscription
    }

    private fun renderTier(
        tierBinding: ViewSubscriptionTierBinding,
        config: SubscriptionTierConfig,
        uiState: TierUiState,
    ) {
        styleTierCard(tierBinding, config)
        populateFeatureRows(tierBinding, config.features)

        if (config.showDogImage) {
            iconLoader.displayImage(AppConstants.LYRIC_PHOTO_URL, tierBinding.imgDog)
        }

        when (uiState) {
            is TierUiState.Active -> showActiveState(tierBinding, config, uiState)
            is TierUiState.Purchase -> showPurchaseState(tierBinding, config, uiState)
        }
    }

    private fun styleTierCard(
        tierBinding: ViewSubscriptionTierBinding,
        config: SubscriptionTierConfig,
    ) {
        tierBinding.root.setCardBackgroundColor(palette.cardBackground)
        tierBinding.root.strokeColor = palette.border
        tierBinding.containerHeader.background =
            createGradientDrawable(
                ContextCompat.getColor(this, config.gradientStartRes),
                ContextCompat.getColor(this, config.gradientEndRes),
                cornerRadiusDp = 0,
            )
        tierBinding.imgHeaderIcon.setImageResource(config.headerIconRes)
        tierBinding.imgHeaderIcon.imageTintList = ColorStateList.valueOf(ContextCompat.getColor(this, R.color.white))
        tierBinding.textHeader.setText(config.headerTitleRes)
        tierBinding.containerDogImage.isVisible = config.showDogImage
        tierBinding.containerDogImage.setBackgroundColor(palette.secondaryBackground)
        tierBinding.containerStatus.setBackgroundColor(palette.secondaryBackground)
        tierBinding.imgDog.strokeColor = ColorStateList.valueOf(ContextCompat.getColor(this, R.color.premium_gold))
        tierBinding.textLoading.setTextColor(palette.secondaryText)
        tierBinding.textActiveMessage.setTextColor(palette.primaryText)
        tierBinding.textActiveRenewal.setTextColor(palette.secondaryText)
        tierBinding.buttonManageSubscription.setTextColor(ContextCompat.getColor(this, R.color.white))
        tierBinding.buttonManageSubscription.backgroundTintList = ColorStateList.valueOf(palette.secondaryText)
    }

    private fun populateFeatureRows(
        tierBinding: ViewSubscriptionTierBinding,
        features: List<SubscriptionFeature>,
    ) {
        val inflater = LayoutInflater.from(this)
        tierBinding.containerFeatures.removeAllViews()

        features.forEachIndexed { index, feature ->
            val featureBinding = ViewSubscriptionFeatureRowBinding.inflate(inflater, tierBinding.containerFeatures, false)
            val iconColor = ContextCompat.getColor(this, feature.colorRes)

            featureBinding.textTitle.setText(feature.titleRes)
            featureBinding.textTitle.setTextColor(if (feature.upcoming) palette.secondaryText else palette.primaryText)
            featureBinding.textUpcoming.setTextColor(palette.secondaryText)
            featureBinding.textUpcoming.isVisible = feature.upcoming
            featureBinding.imgIcon.setImageResource(feature.iconRes)
            featureBinding.imgIcon.imageTintList = ColorStateList.valueOf(iconColor)
            featureBinding.containerIcon.background =
                createCircleDrawable(
                    iconColor = iconColor,
                    alphaFraction = if (feature.upcoming) 0.08f else 0.15f,
                )
            featureBinding.root.alpha = if (feature.upcoming) 0.6f else 1f

            tierBinding.containerFeatures.addView(featureBinding.root)

            if (index < features.lastIndex) {
                tierBinding.containerFeatures.addView(createDivider())
            }
        }
    }

    private fun createDivider(): View =
        View(this).apply {
            setBackgroundColor(palette.border)
            layoutParams =
                android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                    dp(1),
                ).apply {
                    marginStart = dp(52)
                    marginEnd = dp(16)
                }
        }

    private fun showActiveState(
        tierBinding: ViewSubscriptionTierBinding,
        config: SubscriptionTierConfig,
        uiState: TierUiState.Active,
    ) {
        tierBinding.textLoading.isVisible = false
        tierBinding.containerPurchase.isVisible = false
        tierBinding.containerActivated.isVisible = true
        tierBinding.imgActiveIcon.imageTintList = ColorStateList.valueOf(ContextCompat.getColor(this, config.gradientStartRes))
        tierBinding.textActiveMessage.setText(uiState.messageRes)
        tierBinding.textActiveRenewal.text = activeSubscriptionState.renewalMessage
        tierBinding.textActiveRenewal.isVisible = !activeSubscriptionState.renewalMessage.isNullOrBlank()
        tierBinding.buttonManageSubscription.isVisible = uiState.showManage
        tierBinding.buttonManageSubscription.setOnClickListener(
            if (uiState.showManage) {
                View.OnClickListener { openSubscriptionManagement(uiState.manageProductId) }
            } else {
                null
            },
        )
        tierBinding.buttonPurchase.setOnClickListener(null)
    }

    private fun showPurchaseState(
        tierBinding: ViewSubscriptionTierBinding,
        config: SubscriptionTierConfig,
        uiState: TierUiState.Purchase,
    ) {
        val productDetails = availableSubscriptions[config.productId]
        val productOffer = productDetails?.subscriptionOfferDetails?.firstOrNull()
        val pricingPhase = productOffer?.pricingPhases?.pricingPhaseList?.firstOrNull()

        if (productDetails == null || productOffer == null || pricingPhase == null) {
            tierBinding.containerActivated.isVisible = false
            tierBinding.containerPurchase.isVisible = false
            tierBinding.textLoading.isVisible = true
            tierBinding.textLoading.text =
                when {
                    billingErrorMessage != null -> billingErrorMessage
                    availableSubscriptions.isNotEmpty() -> getString(R.string.subscription_unavailable)
                    else -> getString(R.string.loading)
                }
            return
        }

        tierBinding.containerActivated.isVisible = false
        tierBinding.textLoading.isVisible = false
        tierBinding.containerPurchase.isVisible = true
        tierBinding.textPurchaseTitle.text =
            productDetails.name.takeUnless { it.isBlank() } ?: getString(config.purchaseTitleRes)
        tierBinding.textPurchasePrice.text = formatProductPricing(pricingPhase)
        tierBinding.textPurchaseSubtitle.isVisible = uiState.subtitleRes != null
        uiState.subtitleRes?.let(tierBinding.textPurchaseSubtitle::setText)

        tierBinding.buttonPurchase.background =
            createGradientDrawable(
                startColor = ContextCompat.getColor(this, config.gradientStartRes),
                endColor = ContextCompat.getColor(this, config.gradientEndRes),
                cornerRadiusDp = 14,
            )
        tierBinding.buttonPurchase.elevation = dpF(8)
        tierBinding.buttonPurchase.setOnClickListener {
            subscriptionManager.purchaseSubscription(this, productDetails, productOffer)
        }
        tierBinding.buttonManageSubscription.setOnClickListener(null)
    }

    private fun premiumUiState(): TierUiState =
        when {
            activeSubscriptionState.isPro ->
                TierUiState.Active(
                    messageRes = R.string.premium_pro_includes_above,
                    showManage = false,
                )

            activeSubscriptionState.isArchive ->
                TierUiState.Active(
                    messageRes = R.string.premium_archive_includes_above,
                    showManage = false,
                )

            activeSubscriptionState.isPremium ->
                TierUiState.Active(
                    messageRes = R.string.premium_subscription_active,
                    showManage = true,
                    manageProductId = AppConstants.PREMIUM_SUB_ID,
                )

            else -> TierUiState.Purchase()
        }

    private fun archiveUiState(): TierUiState =
        when {
            activeSubscriptionState.isPro ->
                TierUiState.Active(
                    messageRes = R.string.premium_pro_includes_above,
                    showManage = false,
                )

            activeSubscriptionState.isArchive ->
                TierUiState.Active(
                    messageRes = R.string.archive_subscription_active,
                    showManage = true,
                    manageProductId = AppConstants.PREMIUM_ARCHIVE_SUB_ID,
                )

            activeSubscriptionState.isPremium ->
                TierUiState.Purchase(
                    subtitleRes = R.string.subscription_upgrade_from_premium,
                )

            else -> TierUiState.Purchase()
        }

    private fun proUiState(): TierUiState =
        when {
            activeSubscriptionState.isPro ->
                TierUiState.Active(
                    messageRes = R.string.pro_subscription_active,
                    showManage = true,
                    manageProductId = AppConstants.PREMIUM_PRO_SUB_ID,
                )

            activeSubscriptionState.isArchive ->
                TierUiState.Purchase(
                    subtitleRes = R.string.subscription_upgrade_from_archive,
                )

            activeSubscriptionState.isPremium ->
                TierUiState.Purchase(
                    subtitleRes = R.string.subscription_upgrade_from_premium,
                )

            else -> TierUiState.Purchase()
        }

    private fun openSubscriptionManagement(productId: String?) {
        val uri =
            Uri
                .parse("https://play.google.com/store/account/subscriptions")
                .buildUpon()
                .appendQueryParameter("package", packageName)
                .apply {
                    if (!productId.isNullOrBlank()) {
                        appendQueryParameter("sku", productId)
                    }
                }.build()
        UIUtils.handleUri(this, prefsRepo, uri)
    }

    private fun formatProductPricing(pricing: ProductDetails.PricingPhase): String {
        val formattedPrice = pricing.formattedPrice
        return when (pricing.billingPeriod) {
            "P1Y" -> {
                val monthlyPrice = formatCurrency(pricing.priceAmountMicros / 12.0, pricing.priceCurrencyCode)
                getString(R.string.subscription_price_yearly, formattedPrice, monthlyPrice)
            }

            "P1M" -> getString(R.string.subscription_price_monthly, formattedPrice)
            else -> getString(R.string.subscription_price_generic, formattedPrice, readableBillingPeriod(pricing.billingPeriod))
        }
    }

    private fun formatCurrency(
        amountMicros: Double,
        currencyCode: String,
    ): String {
        val formatter = NumberFormat.getCurrencyInstance(Locale.getDefault())
        formatter.currency = Currency.getInstance(currencyCode)
        return formatter.format(amountMicros / 1_000_000.0)
    }

    private fun readableBillingPeriod(billingPeriod: String): String =
        when {
            billingPeriod.contains("Y") -> "year"
            billingPeriod.contains("M") -> "month"
            billingPeriod.contains("W") -> "week"
            else -> billingPeriod.removePrefix("P").lowercase(Locale.getDefault())
        }

    private fun createGradientDrawable(
        startColor: Int,
        endColor: Int,
        cornerRadiusDp: Int,
    ): GradientDrawable =
        GradientDrawable(
            GradientDrawable.Orientation.LEFT_RIGHT,
            intArrayOf(startColor, endColor),
        ).apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dpF(cornerRadiusDp)
        }

    private fun createCircleDrawable(
        iconColor: Int,
        alphaFraction: Float,
    ): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(ColorUtils.setAlphaComponent(iconColor, (255 * alphaFraction).roundToInt()))
        }

    private fun buildPalette(): SubscriptionPalette {
        return when (prefsRepo.getSelectedTheme()) {
            ThemeValue.SEPIA ->
                SubscriptionPalette(
                    background = ContextCompat.getColor(this, R.color.primary_sepia),
                    cardBackground = ContextCompat.getColor(this, R.color.item_background_sepia),
                    secondaryBackground = ContextCompat.getColor(this, R.color.share_bar_background_sepia),
                    primaryText = ContextCompat.getColor(this, R.color.text_sepia),
                    secondaryText = ContextCompat.getColor(this, R.color.button_text_sepia),
                    border = ContextCompat.getColor(this, R.color.row_border_sepia),
                )

            ThemeValue.DARK, ThemeValue.BLACK ->
                SubscriptionPalette(
                    background = Color.parseColor("#1C1C1E"),
                    cardBackground = Color.parseColor("#2C2C2E"),
                    secondaryBackground = Color.parseColor("#38383A"),
                    primaryText = ContextCompat.getColor(this, R.color.gray95),
                    secondaryText = Color.parseColor("#98989D"),
                    border = Color.parseColor("#48484A"),
                )

            ThemeValue.AUTO ->
                if ((resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES) {
                    SubscriptionPalette(
                        background = Color.parseColor("#1C1C1E"),
                        cardBackground = Color.parseColor("#2C2C2E"),
                        secondaryBackground = Color.parseColor("#38383A"),
                        primaryText = ContextCompat.getColor(this, R.color.gray95),
                        secondaryText = Color.parseColor("#98989D"),
                        border = Color.parseColor("#48484A"),
                    )
                } else {
                    SubscriptionPalette(
                        background = ContextCompat.getColor(this, R.color.feed_list_row_background),
                        cardBackground = ContextCompat.getColor(this, R.color.white),
                        secondaryBackground = Color.parseColor("#F7F7F5"),
                        primaryText = Color.parseColor("#1C1C1E"),
                        secondaryText = Color.parseColor("#6E6E73"),
                        border = ContextCompat.getColor(this, R.color.gray85),
                    )
                }

            ThemeValue.LIGHT ->
                SubscriptionPalette(
                    background = ContextCompat.getColor(this, R.color.feed_list_row_background),
                    cardBackground = ContextCompat.getColor(this, R.color.white),
                    secondaryBackground = Color.parseColor("#F7F7F5"),
                    primaryText = Color.parseColor("#1C1C1E"),
                    secondaryText = Color.parseColor("#6E6E73"),
                    border = ContextCompat.getColor(this, R.color.gray85),
                )
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).roundToInt()

    private fun dpF(value: Int): Float = value * resources.displayMetrics.density
}
