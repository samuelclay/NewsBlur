package com.newsblur.activity;

import android.graphics.Paint;
import android.net.Uri;
import android.os.Bundle;
import android.text.util.Linkify;
import android.util.Log;

import androidx.annotation.NonNull;

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
import com.newsblur.util.AppConstants;
import com.newsblur.util.BetterLinkMovementMethod;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;

import java.util.ArrayList;
import java.util.List;

public class Premium extends NbActivity {

    private ActivityPremiumBinding binding;
    private BillingClient billingClient;

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
        binding.textSubscriptionTitle.setPaintFlags(binding.textSubscriptionTitle.getPaintFlags() | Paint.UNDERLINE_TEXT_FLAG);
        FeedUtils.iconLoader.displayImage(AppConstants.SHILOH_PHOTO_URL, binding.imgShiloh, 0, false);
    }

    private void setupBillingClient() {
        PurchasesUpdatedListener purchaseUpdateListener = (billingResult, purchases) -> {
            // To be implemented
            if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK && purchases != null) {
                for (Purchase purchase : purchases) {
                    // handle purchase
                }
            } else if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.USER_CANCELED) {
                // Handle an error caused by a user cancelling the purchase flow.
            } else {
                // Handle any other error codes.
            }
        };

        billingClient = BillingClient.newBuilder(this)
                .setListener(purchaseUpdateListener)
                .enablePendingPurchases()
                .build();

        billingClient.startConnection(new BillingClientStateListener() {
            @Override
            public void onBillingSetupFinished(@NonNull BillingResult billingResult) {
                if (billingResult.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                    // The BillingClient is ready. You can query purchases here.
                    Log.d(Premium.this.getLocalClassName(), "onBillingSetupFinished - message: " + billingResult.getDebugMessage() + " | response code: " + billingResult.getResponseCode());
                }
            }

            @Override
            public void onBillingServiceDisconnected() {
                Log.d(Premium.this.getLocalClassName(), "onBillingServiceDisconnected");
                // Try to restart the connection on the next request to
                // Google Play by calling the startConnection() method.
            }
        });

        List<String> skuList = new ArrayList<>();
        // add sub SKUs from Play Store
        skuList.add("premium_subscription");
        SkuDetailsParams.Builder params = SkuDetailsParams.newBuilder();
        params.setSkusList(skuList).setType(BillingClient.SkuType.SUBS);
        billingClient.querySkuDetailsAsync(params.build(), (billingResult, skuDetailsList) -> {
            // Process the result.
            Log.d(Premium.this.getLocalClassName(), "SkuDetailsResponse - result message: " + billingResult.getDebugMessage() + " | result response code: " + billingResult.getResponseCode());
            if (skuDetailsList != null) {
                for (SkuDetails skuDetails : skuDetailsList) {
                    Log.d(Premium.this.getLocalClassName(), "Sku detail: " + skuDetails.getTitle() + " | " + skuDetails.getDescription() + " | " + skuDetails.getPrice() + " | " + skuDetails.getSku());
                }
            } else {
                Log.d(Premium.this.getLocalClassName(), "Empty sku list");
            }
        });
    }

    private void launchBillingFlow(@NonNull SkuDetails skuDetails) {
        Log.d(Premium.this.getLocalClassName(), "launchBillingFlow");
        // Retrieve a value for "skuDetails" by calling querySkuDetailsAsync().
        BillingFlowParams billingFlowParams = BillingFlowParams.newBuilder()
                .setSkuDetails(skuDetails)
                .build();
        int responseCode = billingClient.launchBillingFlow(this, billingFlowParams).getResponseCode();

        // Handle the result.

    }
}
