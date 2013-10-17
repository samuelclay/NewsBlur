package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.service.SyncService;
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
        readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), getContentResolver(), stories);

        setupPager();

        addStoryToMarkAsRead(readingAdapter.getStory(passedPosition));
    }

    @Override
    public void triggerRefresh(int page) {
        setSupportProgressBarIndeterminateVisibility(true);
        final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
        intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
        intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.MULTISOCIALFEED_UPDATE);
        intent.putExtra(SyncService.EXTRA_TASK_MULTIFEED_IDS, new String[0]); // query for all shared storis via wildcard
        if (page > 1) {
            intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
        }
        intent.putExtra(SyncService.EXTRA_TASK_ORDER, PrefsUtils.getStoryOrderForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME));
        intent.putExtra(SyncService.EXTRA_TASK_READ_FILTER, PrefsUtils.getReadFilterForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME));
        startService(intent);
    }

}
