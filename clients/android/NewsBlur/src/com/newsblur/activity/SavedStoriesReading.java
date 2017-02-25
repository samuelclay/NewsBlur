package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.util.UIUtils;

public class SavedStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        String title = getResources().getString(R.string.saved_stories_title);
        if (fs.getSingleSavedTag() != null) {
            title = title + " - " + fs.getSingleSavedTag();
        }
        UIUtils.setCustomActionBar(this, R.drawable.clock, title);
        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), defaultFeedView, null);

        getLoaderManager().initLoader(0, null, this);
    }

}
