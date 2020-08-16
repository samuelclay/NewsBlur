package com.newsblur.activity;

import android.graphics.Paint;
import android.net.Uri;
import android.os.Bundle;
import android.text.util.Linkify;

import com.newsblur.R;
import com.newsblur.databinding.ActivityPremiumBinding;
import com.newsblur.util.AppConstants;
import com.newsblur.util.BetterLinkMovementMethod;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;

public class Premium extends NbActivity {

    private ActivityPremiumBinding binding;

    @Override
    protected void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        binding = ActivityPremiumBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

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
}
