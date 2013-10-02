package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.service.SyncService;

public class SavedStoriesReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        stories = contentResolver.query(FeedProvider.STARRED_STORIES_URI, null, null, null, null);
        setTitle(getResources().getString(R.string.saved_stories_title));
        readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), getContentResolver(), stories);

        setupPager();
    }
    
    @Override
    public void triggerRefresh(int page) {
        setSupportProgressBarIndeterminateVisibility(true);
        final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
        intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
        intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.STARRED_STORIES_UPDATE);
        if (page > 1) {
            intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
        }
        startService(intent);
    }

}
