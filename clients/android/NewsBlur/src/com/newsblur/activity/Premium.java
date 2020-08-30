package com.newsblur.activity;

import android.graphics.Paint;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Bundle;
import android.text.format.DateUtils;
import android.text.util.Linkify;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.AcknowledgePurchaseResponseListener;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.SkuDetails;
import com.android.billingclient.api.SkuDetailsParams;
import com.newsblur.R;
import com.newsblur.databinding.ActivityPremiumBinding;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;
import com.newsblur.util.BetterLinkMovementMethod;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.Log;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.UIUtils;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.TimeZone;

public class Premium extends NbActivity {

    private ActivityPremiumBinding binding;
    private BillingClient billingClient;
    private SkuDetails subscriptionDetails;
    private Purchase purchasedSubscription;

    private AcknowledgePurchaseResponseListener acknowledgePurchaseResponseListener = billingResult -> {
        if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
            Log.d(Premium.this.getLocalClassName(), "acknowledgePurchaseResponseListener OK");
            verifyUserSubscriptionStatus();
        } else if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.BILLING_UNAVAILABLE) {
            // Billing API version is not supported for the type requested.
            Log.d(Premium.this.getLocalClassName(), "acknowledgePurchaseResponseListener BILLING_UNAVAILABLE");
        } else if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE) {
            // Network connection is down.
            Log.d(Premium.this.getLocalClassName(), "acknowledgePurchaseResponseListener SERVICE_UNAVAILABLE");
        } else {
            // Handle any other error codes.
            Log.d(Premium.this.getLocalClassName(), "acknowledgePurchaseResponseListener ERROR - message: " + billingResult.getDebugMessage());
        }
    };

    private PurchasesUpdatedListener purchaseUpdateListener = (billingResult, purchases) -> {
        if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK && purchases != null) {
            Log.d(Premium.this.getLocalClassName(), "purchaseUpdateListener OK");
            for (Purchase purchase : purchases) {
                handlePurchase(purchase);
            }
        } else if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.USER_CANCELED) {
            // Handle an error caused by a user cancelling the purchase flow.
            Log.d(Premium.this.getLocalClassName(), "purchaseUpdateListener USER_CANCELLED");
        } else if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.BILLING_UNAVAILABLE) {
            // Billing API version is not supported for the type requested.
            Log.d(Premium.this.getLocalClassName(), "purchaseUpdateListener BILLING_UNAVAILABLE");
        } else if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE) {
            // Network connection is down.
            Log.d(Premium.this.getLocalClassName(), "purchaseUpdateListener SERVICE_UNAVAILABLE");
        } else {
            // Handle any other error codes.
            Log.d(Premium.this.getLocalClassName(), "purchaseUpdateListener ERROR - message: " + billingResult.getDebugMessage());
        }
    };

    private BillingClientStateListener billingClientStateListener = new BillingClientStateListener() {
        @Override
        public void onBillingSetupFinished(@NonNull BillingResult billingResult) {
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                // The BillingClient is ready. You can query purchases here.
                Log.d(Premium.this.getLocalClassName(), "onBillingSetupFinished OK");
                retrievePlayStoreSubscriptions();
                verifyUserSubscriptionStatus();
            } else {
                showSubscriptionDetailsError();
            }
        }

        @Override
        public void onBillingServiceDisconnected() {
            Log.d(Premium.this.getLocalClassName(), "onBillingServiceDisconnected");
            // Try to restart the connection on the next request to
            // Google Play by calling the startConnection() method.
            showSubscriptionDetailsError();
        }
    };

    @Override
    protected void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        binding = ActivityPremiumBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        setupUI();
        setupBillingClient();
    }

    private void setupUI() {
        UIUtils.setCustomActionBar(this, R.drawable.logo, getString(R.string.premium_toolbar_title));

        // linkify before setting the string resource
        BetterLinkMovementMethod.linkify(Linkify.WEB_URLS, binding.textPolicies)
                .setOnLinkClickListener((textView, url) -> {
                    UIUtils.handleUri(Premium.this, Uri.parse(url));
                    return true;
                });
        binding.textPolicies.setText(UIUtils.fromHtml(getString(R.string.premium_policies)));
        binding.textSubTitle.setPaintFlags(binding.textSubTitle.getPaintFlags() | Paint.UNDERLINE_TEXT_FLAG);
        FeedUtils.iconLoader.displayImage(AppConstants.SHILOH_PHOTO_URL, binding.imgShiloh, 0, false);
    }

    private void setupBillingClient() {
        billingClient = BillingClient.newBuilder(this)
                .setListener(purchaseUpdateListener)
                .enablePendingPurchases()
                .build();

        billingClient.startConnection(billingClientStateListener);
    }

    private void verifyUserSubscriptionStatus() {
        boolean hasNewsBlurSubscription = PrefsUtils.isPremium(this);
        Purchase playStoreSubscription = null;
        Purchase.PurchasesResult result = billingClient.queryPurchases(BillingClient.SkuType.SUBS);
        if (result.getPurchasesList() != null) {
            for (Purchase purchase : result.getPurchasesList()) {
                if (purchase.getSku().equals(AppConstants.PREMIUM_SKU)) {
                    playStoreSubscription = purchase;
                }
            }
        }

        if (hasNewsBlurSubscription || playStoreSubscription != null) {
            binding.containerGoingPremium.setVisibility(View.GONE);
            binding.containerGonePremium.setVisibility(View.VISIBLE);

            if (playStoreSubscription != null) {
                long expirationTimeMs = playStoreSubscription.getPurchaseTime() + DateUtils.YEAR_IN_MILLIS;
                Date expirationDate = new Date(expirationTimeMs);
                DateFormat dateFormat = new SimpleDateFormat("EEE, MMMM d, yyyy", Locale.getDefault());
                dateFormat.setTimeZone(TimeZone.getDefault());
                String renewalString;
                if (playStoreSubscription.isAutoRenewing()) {
                    renewalString = getString(R.string.premium_subscription_renewal, dateFormat.format(expirationDate));
                } else {
                    renewalString = getString(R.string.premium_subscription_expiration, dateFormat.format(expirationDate));
                }
                binding.textSubscriptionRenewal.setText(renewalString);
                binding.textSubscriptionRenewal.setVisibility(View.VISIBLE);
            }
        }

        if (!hasNewsBlurSubscription && playStoreSubscription != null) {
            purchasedSubscription = playStoreSubscription;
            notifyNewsBlurOfSubscription();
        }
    }

    private void retrievePlayStoreSubscriptions() {
        List<String> skuList = new ArrayList<>(1);
        // add sub SKUs from Play Store
        skuList.add(AppConstants.PREMIUM_SKU);
        SkuDetailsParams.Builder params = SkuDetailsParams.newBuilder();
        params.setSkusList(skuList).setType(BillingClient.SkuType.SUBS);
        billingClient.querySkuDetailsAsync(params.build(), (billingResult, skuDetailsList) -> {
            Log.d(Premium.this.getLocalClassName(), "SkuDetailsResponse");
            processSkuDetailsList(skuDetailsList);
        });
    }

    private void processSkuDetailsList(@Nullable List<SkuDetails> skuDetailsList) {
        if (skuDetailsList != null) {
            for (SkuDetails skuDetails : skuDetailsList) {
                if (skuDetails.getSku().equals(AppConstants.PREMIUM_SKU)) {
                    Log.d(Premium.this.getLocalClassName(), "Sku detail: " + skuDetails.getTitle() + " | " + skuDetails.getDescription() + " | " + skuDetails.getPrice() + " | " + skuDetails.getSku());
                    subscriptionDetails = skuDetails;
                }
            }
        }

        if (subscriptionDetails != null) {
            showSubscriptionDetails();
        } else {
            showSubscriptionDetailsError();
        }
    }

    private void showSubscriptionDetailsError() {
        binding.textLoading.setText(R.string.premium_subscription_details_error);
        binding.textLoading.setVisibility(View.VISIBLE);
        binding.containerSub.setVisibility(View.GONE);
    }

    private void showSubscriptionDetails() {
        // handling dynamic currency and pricing for 1Y subscriptions
        String currencySymbol = subscriptionDetails.getPrice().substring(0, 1);
        String priceString = subscriptionDetails.getPrice().substring(1);
        double price = Double.parseDouble(priceString);
        StringBuilder pricingText = new StringBuilder();
        pricingText.append(subscriptionDetails.getPrice());
        pricingText.append(" per year (");
        pricingText.append(currencySymbol);
        pricingText.append(String.format(Locale.getDefault(), "%.2f", price / 12));
        pricingText.append("/month)");

        binding.textSubTitle.setText(subscriptionDetails.getTitle());
        binding.textSubPrice.setText(pricingText);
        binding.textLoading.setVisibility(View.GONE);
        binding.containerSub.setVisibility(View.VISIBLE);
        binding.containerSub.setOnClickListener(view -> launchBillingFlow(subscriptionDetails));
    }

    private void launchBillingFlow(@NonNull SkuDetails skuDetails) {
        Log.d(Premium.this.getLocalClassName(), "launchBillingFlow for sku: " + skuDetails.getSku());
        BillingFlowParams billingFlowParams = BillingFlowParams.newBuilder()
                .setSkuDetails(skuDetails)
                .build();
        billingClient.launchBillingFlow(this, billingFlowParams);
    }

    private void handlePurchase(Purchase purchase) {
        Log.d(Premium.this.getLocalClassName(), "handlePurchase: " + purchase.getOrderId());
        purchasedSubscription = purchase;
        if (purchase.getPurchaseState() == Purchase.PurchaseState.PURCHASED && purchase.isAcknowledged()) {
            verifyUserSubscriptionStatus();
        } else if (purchase.getPurchaseState() == Purchase.PurchaseState.PURCHASED && !purchase.isAcknowledged()) {
            // need to acknowledge first time sub otherwise it will void
            Log.d(Premium.this.getLocalClassName(), "acknowledge purchase: " + purchase.getOrderId());
            AcknowledgePurchaseParams acknowledgePurchaseParams =
                    AcknowledgePurchaseParams.newBuilder()
                            .setPurchaseToken(purchase.getPurchaseToken())
                            .build();
            billingClient.acknowledgePurchase(acknowledgePurchaseParams, acknowledgePurchaseResponseListener);
        }
    }

    private void notifyNewsBlurOfSubscription() {
        if (purchasedSubscription != null) {
            APIManager apiManager = new APIManager(this);
            new AsyncTask<Void, Void, NewsBlurResponse>() {
                @Override
                protected NewsBlurResponse doInBackground(Void... voids) {
                    return apiManager.saveReceipt(purchasedSubscription.getOrderId(), purchasedSubscription.getSku());
                }

                @Override
                protected void onPostExecute(NewsBlurResponse result) {
                    super.onPostExecute(result);
                    if (!result.isError()) {
                        NBSyncService.forceFeedsFolders();
                        triggerSync();
                    }
                    finish();
                }
            }.execute();
        }
    }
}
