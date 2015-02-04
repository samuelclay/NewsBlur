package com.newsblur.activity;

import android.os.Bundle;
import android.view.Menu;

import com.newsblur.R;
import com.newsblur.database.MixedFeedsReadingAdapter;

public class GlobalSharedStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        setTitle(getResources().getString(R.string.global_shared_stories));
        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), defaultFeedView, null);

        getLoaderManager().initLoader(0, null, this);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        super.onCreateOptionsMenu(menu);
        menu.removeItem(R.id.menu_reading_markunread);
        return true;
    }
}
