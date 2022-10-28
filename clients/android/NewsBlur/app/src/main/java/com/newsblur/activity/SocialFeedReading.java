package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.domain.SocialFeed;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;

public class SocialFeedReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);
        SocialFeed socialFeed = dbHelper.getSocialFeed(fs.getSingleSocialFeed().getKey());
        if (socialFeed == null) finish(); // don't open fatally stale intents
        UIUtils.setupToolbar(this, socialFeed.photoUrl, socialFeed.feedTitle, iconLoader, false);
    }

}
