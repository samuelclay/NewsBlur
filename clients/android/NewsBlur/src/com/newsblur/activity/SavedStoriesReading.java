package com.newsblur.activity;

import android.database.Cursor;
import android.os.Bundle;
import android.support.v4.content.CursorLoader;
import android.support.v4.content.Loader;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.StoryOrder;

public class SavedStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        setTitle(getResources().getString(R.string.saved_stories_title));
        readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), getContentResolver(), defaultFeedView);

        getSupportLoaderManager().initLoader(0, null, this);
    }

    @Override
    protected int getUnreadCount() {
        // effectively disable the notion of unreads for this feed
        return 0;
    }

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
        return new CursorLoader(this, FeedProvider.STARRED_STORIES_URI, null, null, null, DatabaseConstants.STARRED_STORY_ORDER);
    }
    
    @Override
    protected void triggerRefresh(int page) {
        FeedUtils.updateSavedStories(this, this, page);
    }

}
