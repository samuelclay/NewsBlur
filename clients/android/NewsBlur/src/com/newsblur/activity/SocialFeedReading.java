package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.UIUtils;

public class SocialFeedReading extends Reading {

    private SocialFeed socialFeed;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

	    socialFeed = (SocialFeed) getIntent().getSerializableExtra(EXTRA_SOCIAL_FEED);

        setTitle(socialFeed.feedTitle);
        UIUtils.setActionBarImage(this, socialFeed.photoUrl);

        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), defaultFeedView, socialFeed.userId);

        getLoaderManager().initLoader(0, null, this);
    }

}
