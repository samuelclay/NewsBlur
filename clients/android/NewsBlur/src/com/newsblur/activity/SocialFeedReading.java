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
import com.newsblur.domain.SocialFeed;
import com.newsblur.service.SyncService;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryOrder;

public class SocialFeedReading extends Reading {

    private String userId;
    private String username;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        userId = getIntent().getStringExtra(Reading.EXTRA_USERID);
        username = getIntent().getStringExtra(Reading.EXTRA_USERNAME);

        setTitle(getIntent().getStringExtra(EXTRA_USERNAME));

        readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), getContentResolver());

        getSupportLoaderManager().initLoader(0, null, this);
    }

    @Override
    protected int getUnreadCount() {
        Uri socialFeedUri = FeedProvider.SOCIAL_FEEDS_URI.buildUpon().appendPath(userId).build();
        Cursor cursor = contentResolver.query(socialFeedUri, null, null, null, null);
        SocialFeed socialFeed = SocialFeed.fromCursor(cursor);
        cursor.close();
        return FeedUtils.getFeedUnreadCount(socialFeed, this.currentState);
    }

	@Override
	public Loader<Cursor> onCreateLoader(int loaderId, Bundle bundle) {
        Uri storiesURI = FeedProvider.SOCIALFEED_STORIES_URI.buildUpon().appendPath(userId).build();
        return new CursorLoader(this, storiesURI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySharedSortOrder(PrefsUtils.getStoryOrderForFeed(this, userId)));
    }

    @Override
    protected void triggerRefresh(int page) {
        FeedUtils.updateSocialFeed(this, this, userId, username, page, PrefsUtils.getStoryOrderForFeed(this, userId), PrefsUtils.getReadFilterForFeed(this, userId));
    }

}
