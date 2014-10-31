package com.newsblur.activity;

import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.content.CursorLoader;
import android.content.Loader;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.FeedReadingAdapter;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryOrder;

public class FeedReading extends Reading {

    Feed feed;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        feed = (Feed) getIntent().getSerializableExtra(EXTRA_FEED);
        super.onCreate(savedInstanceBundle);

        Uri classifierUri = FeedProvider.CLASSIFIER_URI.buildUpon().appendPath(feed.feedId).build();
        Cursor feedClassifierCursor = contentResolver.query(classifierUri, null, null, null, null);
        Classifier classifier = Classifier.fromCursor(feedClassifierCursor);
        feedClassifierCursor.close();

        setTitle(feed.title);

        readingAdapter = new FeedReadingAdapter(fragmentManager, feed, classifier, defaultFeedView);

        getLoaderManager().initLoader(0, null, this);
    }

}
