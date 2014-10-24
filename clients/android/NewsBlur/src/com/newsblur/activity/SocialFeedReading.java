package com.newsblur.activity;

import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.content.CursorLoader;
import android.content.Loader;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;

public class SocialFeedReading extends Reading {

    private String userId;
    private String username;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        userId = getIntent().getStringExtra(Reading.EXTRA_USERID);
        username = getIntent().getStringExtra(Reading.EXTRA_USERNAME);

        setTitle(getIntent().getStringExtra(EXTRA_USERNAME));

        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), getContentResolver(), defaultFeedView, userId);

        getLoaderManager().initLoader(0, null, this);
    }

}
