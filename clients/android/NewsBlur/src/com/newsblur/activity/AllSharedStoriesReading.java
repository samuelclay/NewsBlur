package com.newsblur.activity;

import android.database.Cursor;
import android.os.Bundle;
import android.content.CursorLoader;
import android.content.Loader;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryOrder;

public class AllSharedStoriesReading extends Reading {

    private String[] feedIds;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        feedIds = getIntent().getStringArrayExtra(Reading.EXTRA_FEED_IDS);
        setTitle(getResources().getString(R.string.all_shared_stories));

        readingAdapter = new MixedFeedsReadingAdapter(getFragmentManager(), getContentResolver(), defaultFeedView);

        getLoaderManager().initLoader(0, null, this);
    }

    @Override
    protected int getUnreadCount() {
        Cursor folderCursor = contentResolver.query(FeedProvider.SOCIALCOUNT_URI, null, DatabaseConstants.getBlogSelectionFromState(currentState), null, null);
        int c = FeedUtils.getCursorUnreadCount(folderCursor, currentState);
        folderCursor.close();
        return c;
    }

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
        StoryOrder storyOrder = PrefsUtils.getStoryOrderForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME);
        return new CursorLoader(this, FeedProvider.ALL_SHARED_STORIES_URI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
    }

    @Override
    protected void triggerRefresh(int page) {
        FeedUtils.updateSocialFeeds(this, this, feedIds, page, PrefsUtils.getStoryOrderForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME), PrefsUtils.getReadFilterForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME));
    }

}
