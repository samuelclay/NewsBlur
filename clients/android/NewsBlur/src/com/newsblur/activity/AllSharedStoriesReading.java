package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.util.UIUtils;

public class AllSharedStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        UIUtils.setCustomActionBar(this, R.drawable.ak_icon_blurblogs, getResources().getString(R.string.all_shared_stories_title));

        // No sourceUserId since this is all shared stories. The sourceUsedId for each story will be used.
        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), null);

        getLoaderManager().initLoader(0, null, this);
    }

}
