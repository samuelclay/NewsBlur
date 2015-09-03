package com.newsblur.activity;

import android.database.Cursor;
import android.os.Bundle;
import android.content.Loader;

import com.newsblur.R;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;

public class SavedStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        UIUtils.setCustomActionBar(this, R.drawable.clock, getResources().getString(R.string.saved_stories_title));
        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), defaultFeedView, null);

        getLoaderManager().initLoader(0, null, this);
    }

    @Override
    public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        // every time we see a set of saved stories, tag them so they don't disappear during this reading session
        FeedUtils.dbHelper.markSavedReadingSession();
        super.onLoadFinished(loader, cursor);
    }
}
