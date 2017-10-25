package com.newsblur.activity;

import android.database.Cursor;
import android.os.Bundle;
import android.content.Loader;

import com.newsblur.R;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.util.UIUtils;

public class ReadStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        UIUtils.setCustomActionBar(this, R.drawable.g_icn_unread, getResources().getString(R.string.read_stories_title));
        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), null);

        getLoaderManager().initLoader(0, null, this);
    }

    @Override
    public void onLoadFinished(Loader<Cursor> loader, Cursor cursor) {
        super.onLoadFinished(loader, cursor);
    }
}
