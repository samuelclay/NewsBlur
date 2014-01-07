package com.newsblur.activity;

import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.content.CursorLoader;
import android.support.v4.content.Loader;

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

        final Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
        Cursor feedCursor = contentResolver.query(feedUri, null, null, null, null);

        feedCursor.moveToFirst();
        feed = Feed.fromCursor(feedCursor);
        feedCursor.close();
        setTitle(feed.title);

        int unreadCount = FeedUtils.getFeedUnreadCount(this.feed, this.currentState);
        this.startingUnreadCount = unreadCount;
        this.currentUnreadCount = unreadCount;

        readingAdapter = new FeedReadingAdapter(getSupportFragmentManager(), feed, classifier);

        addStoryToMarkAsRead(readingAdapter.getStory(passedPosition));

        getSupportLoaderManager().initLoader(0, null, this);
    }

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
        Uri storiesURI = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(feedId).build();
        StoryOrder storyOrder = PrefsUtils.getStoryOrderForFeed(this, feedId);
        return new CursorLoader(this, storiesURI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
    }

    @Override
    protected void triggerRefresh(int page) {
        FeedUtils.updateFeed(this, this, feedId, page, PrefsUtils.getStoryOrderForFeed(this, feedId), PrefsUtils.getReadFilterForFeed(this, feedId));
    }

}
