package com.newsblur.activity;

import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;

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

        Uri storiesURI = FeedProvider.MULTIFEED_STORIES_URI;
        stories = contentResolver.query(storiesURI, null, DatabaseConstants.getStorySelectionFromState(currentState), feedIds, null);

        Cursor folderCursor = contentResolver.query(FeedProvider.FOLDERS_URI.buildUpon().appendPath(folderName).build(), null, null, new String[] { DatabaseConstants.getFolderSelectionFromState(currentState) }, null);
        int unreadCount = FeedUtils.getCursorUnreadCount(folderCursor, currentState);
        folderCursor.close();
        this.startingUnreadCount = unreadCount;
        this.currentUnreadCount = unreadCount;

        readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), getContentResolver(), stories);

        setupPager();

        addStoryToMarkAsRead(readingAdapter.getStory(passedPosition));
    }

    @Override
    public void triggerRefresh(int page) {
        updateSyncStatus(true);
        final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
        intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
        intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.MULTIFEED_UPDATE);
        intent.putExtra(SyncService.EXTRA_TASK_MULTIFEED_IDS, feedIds);
        if (page > 1) {
            intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
        }
        intent.putExtra(SyncService.EXTRA_TASK_ORDER, PrefsUtils.getStoryOrderForFolder(this, folderName));
        intent.putExtra(SyncService.EXTRA_TASK_READ_FILTER, PrefsUtils.getReadFilterForFolder(this, folderName));
        startService(intent);
    }

}
