package com.newsblur.activity;

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
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryOrder;

public class FeedReading extends Reading {

    String feedId;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        feedId = getIntent().getStringExtra(Reading.EXTRA_FEED);

        Uri classifierUri = FeedProvider.CLASSIFIER_URI.buildUpon().appendPath(feedId).build();
        Cursor feedClassifierCursor = contentResolver.query(classifierUri, null, null, null, null);
        Classifier classifier = Classifier.fromCursor(feedClassifierCursor);

        Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
        Cursor feedCursor = contentResolver.query(feedUri, null, null, null, null);
        Feed feed = Feed.fromCursor(feedCursor);
        feedCursor.close();
        setTitle(feed.title);

        readingAdapter = new FeedReadingAdapter(getSupportFragmentManager(), feed, classifier, defaultFeedView);

        getSupportLoaderManager().initLoader(0, null, this);
    }

    @Override
    protected int getUnreadCount() {
        Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
        Cursor feedCursor = contentResolver.query(feedUri, null, null, null, null);
        Feed feed = Feed.fromCursor(feedCursor);
        feedCursor.close();
        return FeedUtils.getFeedUnreadCount(feed, this.currentState);
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
