package com.newsblur.activity;

import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.FeedReadingAdapter;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryOrder;

public class FeedReading extends Reading {

    String feedId;
    private Feed feed;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        feedId = getIntent().getStringExtra(Reading.EXTRA_FEED);

        Uri classifierUri = FeedProvider.CLASSIFIER_URI.buildUpon().appendPath(feedId).build();
        Cursor feedClassifierCursor = contentResolver.query(classifierUri, null, null, null, null);
        Classifier classifier = Classifier.fromCursor(feedClassifierCursor);

        Uri storiesURI = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(feedId).build();
        StoryOrder storyOrder = PrefsUtils.getStoryOrderForFeed(this, feedId);
        stories = contentResolver.query(storiesURI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));

        final Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
        Cursor feedCursor = contentResolver.query(feedUri, null, null, null, null);

        feedCursor.moveToFirst();
        feed = Feed.fromCursor(feedCursor);
        setTitle(feed.title);

        this.unreadCount = FeedUtils.getFeedUnreadCount(this.feed, this.currentState);

        readingAdapter = new FeedReadingAdapter(getSupportFragmentManager(), feed, stories, classifier);

        setupPager();

        addStoryToMarkAsRead(readingAdapter.getStory(passedPosition));
    }

    @Override
    public void triggerRefresh(int page) {
        setSupportProgressBarIndeterminateVisibility(true);
        final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
        intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
        intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.FEED_UPDATE);
        intent.putExtra(SyncService.EXTRA_TASK_FEED_ID, feedId);
        if (page > 1) {
            intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
        }
        intent.putExtra(SyncService.EXTRA_TASK_ORDER, PrefsUtils.getStoryOrderForFeed(this, feedId));
        intent.putExtra(SyncService.EXTRA_TASK_READ_FILTER, PrefsUtils.getReadFilterForFeed(this, feedId));
        startService(intent);
    }

}
