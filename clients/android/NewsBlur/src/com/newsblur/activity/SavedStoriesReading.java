package com.newsblur.activity;

import android.content.Intent;
import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.service.SyncService;
import com.newsblur.util.FeedUtils;

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
        updateSyncStatus(true);
        FeedUtils.updateSavedStories(this, this, page);
    }

}
