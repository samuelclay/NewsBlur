package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.MixedFeedsReadingAdapter;

public class AllStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        setTitle(getResources().getString(R.string.all_stories_row_title));
        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), defaultFeedView, null);
        getLoaderManager().initLoader(0, null, this);
    }

}
