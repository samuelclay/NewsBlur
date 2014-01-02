package com.newsblur.activity;

import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.service.SyncService;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryOrder;

public class AllSharedStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        StoryOrder storyOrder = PrefsUtils.getStoryOrderForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME);
        stories = contentResolver.query(FeedProvider.ALL_SHARED_STORIES_URI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
        setTitle(getResources().getString(R.string.all_shared_stories));

        Cursor folderCursor = contentResolver.query(FeedProvider.SOCIALCOUNT_URI, null, DatabaseConstants.getBlogSelectionFromState(currentState), null, null);
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
        FeedUtils.updateSocialFeeds(this, this, new String[0], page, PrefsUtils.getStoryOrderForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME), PrefsUtils.getReadFilterForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME));
    }

}
