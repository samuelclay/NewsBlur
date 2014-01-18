package com.newsblur.activity;

import android.database.Cursor;
import android.os.Bundle;
import android.support.v4.content.CursorLoader;
import android.support.v4.content.Loader;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;

public class FolderReading extends Reading {

    private String[] feedIds;
    private String folderName;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        feedIds = getIntent().getStringArrayExtra(Reading.EXTRA_FEED_IDS);
        folderName = getIntent().getStringExtra(Reading.EXTRA_FOLDERNAME);
        setTitle(folderName);       

        readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), getContentResolver(), defaultFeedView);

        getSupportLoaderManager().initLoader(0, null, this);
    }

    @Override
    protected int getUnreadCount() {
        Cursor folderCursor = contentResolver.query(FeedProvider.FOLDERS_URI.buildUpon().appendPath(folderName).build(), null, null, new String[] { DatabaseConstants.getFolderSelectionFromState(currentState) }, null);
        int c = FeedUtils.getCursorUnreadCount(folderCursor, currentState);
        folderCursor.close();
        return c;
    }

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
        return new CursorLoader(this, FeedProvider.MULTIFEED_STORIES_URI, null, DatabaseConstants.getStorySelectionFromState(currentState), feedIds, DatabaseConstants.getStorySortOrder(PrefsUtils.getStoryOrderForFolder(this, folderName)));
    }

    @Override
    protected void triggerRefresh(int page) {
        FeedUtils.updateFeeds(this, this, feedIds, page, PrefsUtils.getStoryOrderForFolder(this, folderName), PrefsUtils.getReadFilterForFolder(this, folderName));
    }

}
