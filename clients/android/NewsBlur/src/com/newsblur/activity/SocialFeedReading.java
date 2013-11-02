package com.newsblur.activity;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

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
    private SocialFeed socialFeed;

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        userId = getIntent().getStringExtra(Reading.EXTRA_USERID);
        username = getIntent().getStringExtra(Reading.EXTRA_USERNAME);

        Uri socialFeedUri = FeedProvider.SOCIAL_FEEDS_URI.buildUpon().appendPath(userId).build();
        socialFeed = SocialFeed.fromCursor(contentResolver.query(socialFeedUri, null, null, null, null));

        Uri storiesURI = FeedProvider.SOCIALFEED_STORIES_URI.buildUpon().appendPath(userId).build();
        stories = contentResolver.query(storiesURI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, null);
        setTitle(getIntent().getStringExtra(EXTRA_USERNAME));

        int unreadCount = FeedUtils.getFeedUnreadCount(this.socialFeed, this.currentState);
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
        intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.SOCIALFEED_UPDATE);
        intent.putExtra(SyncService.EXTRA_TASK_SOCIALFEED_ID, userId);
        if (page > 1) {
            intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
        }
        intent.putExtra(SyncService.EXTRA_TASK_SOCIALFEED_USERNAME, username);
        intent.putExtra(SyncService.EXTRA_TASK_ORDER, PrefsUtils.getStoryOrderForFeed(this, userId));
        intent.putExtra(SyncService.EXTRA_TASK_READ_FILTER, PrefsUtils.getReadFilterForFeed(this, userId));
        startService(intent);
    }

}
