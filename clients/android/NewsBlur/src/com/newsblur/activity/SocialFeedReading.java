package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;

public class SocialFeedReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);
        SocialFeed socialFeed = FeedUtils.dbHelper.getSocialFeed(fs.getSingleSocialFeed().getKey());
        if (socialFeed == null) finish(); // don't open fatally stale intents
        UIUtils.setCustomActionBar(this, socialFeed.photoUrl, socialFeed.feedTitle);
        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), defaultFeedView, socialFeed.userId);
        getLoaderManager().initLoader(0, null, this);
    }

}
