package com.newsblur.activity;

import android.database.Cursor;
import android.os.Bundle;
import android.content.CursorLoader;
import android.content.Loader;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.StoryOrder;

public class SavedStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        setTitle(getResources().getString(R.string.saved_stories_title));
        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), getContentResolver(), defaultFeedView, null);

        getLoaderManager().initLoader(0, null, this);
    }

    @Override
    protected int getUnreadCount() {
        // effectively disable the notion of unreads for this feed
        return 0;
    }

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
		return dbHelper.getSavedStoriesLoader();
    }
    
}
