package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.domain.SocialFeed;
import com.newsblur.util.UIUtils;

public class SocialFeedReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);
        new Thread(() -> {
            SocialFeed socialFeed = dbHelper.getSocialFeed(fs.getSingleSocialFeed().getKey());
            if (socialFeed != null) {
                runOnUiThread(() -> UIUtils.setupToolbar(this, socialFeed.photoUrl, socialFeed.feedTitle, iconLoader, false));
            } else {
                runOnUiThread(this::finish);
            }
        }).start();
    }

}
