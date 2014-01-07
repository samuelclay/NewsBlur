package com.newsblur.activity;

import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.content.CursorLoader;
import android.support.v4.content.Loader;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.service.SyncService;
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

        Cursor folderCursor = contentResolver.query(FeedProvider.FOLDERS_URI.buildUpon().appendPath(folderName).build(), null, null, new String[] { DatabaseConstants.getFolderSelectionFromState(currentState) }, null);
        int unreadCount = FeedUtils.getCursorUnreadCount(folderCursor, currentState);
        folderCursor.close();
        this.startingUnreadCount = unreadCount;
        this.currentUnreadCount = unreadCount;

        readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), getContentResolver());

        addStoryToMarkAsRead(readingAdapter.getStory(passedPosition));

        getSupportLoaderManager().initLoader(0, null, this);
    }

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
        return new CursorLoader(this, FeedProvider.MULTIFEED_STORIES_URI, null, DatabaseConstants.getStorySelectionFromState(currentState), feedIds, null);
    }

    @Override
    protected void triggerRefresh(int page) {
        FeedUtils.updateFeeds(this, this, feedIds, page, PrefsUtils.getStoryOrderForFolder(this, folderName), PrefsUtils.getReadFilterForFolder(this, folderName));
    }

}
