package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.database.MixedFeedsReadingAdapter;

public class SocialFeedReading extends Reading {

    private String userId;
    private String username;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        userId = getIntent().getStringExtra(Reading.EXTRA_USERID);
        username = getIntent().getStringExtra(Reading.EXTRA_USERNAME);

        setTitle(getIntent().getStringExtra(EXTRA_USERNAME));

        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), defaultFeedView, userId);

        getLoaderManager().initLoader(0, null, this);
    }

}
