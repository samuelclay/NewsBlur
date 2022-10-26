package com.newsblur.activity;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.DialogFragment;
import android.view.Menu;
import android.view.MenuItem;

import com.google.android.play.core.review.ReviewInfo;
import com.google.android.play.core.review.ReviewManager;
import com.google.android.play.core.review.ReviewManagerFactory;
import com.google.android.play.core.tasks.Task;
import com.newsblur.R;
import com.newsblur.di.IconLoader;
import com.newsblur.domain.Feed;
import com.newsblur.fragment.DeleteFeedFragment;
import com.newsblur.fragment.FeedIntelTrainerFragment;
import com.newsblur.fragment.RenameDialogFragment;
import com.newsblur.util.FeedExt;
import com.newsblur.util.FeedSet;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.Session;
import com.newsblur.util.SessionDataSource;
import com.newsblur.util.UIUtils;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class FeedItemsList extends ItemsList {

    @Inject
    @IconLoader
    ImageLoader iconLoader;

    public static final String EXTRA_FEED = "feed";
    public static final String EXTRA_FOLDER_NAME = "folderName";
	private Feed feed;
	private String folderName;
	private ReviewManager reviewManager;
	private ReviewInfo reviewInfo;

    public static void startActivity(Context context, FeedSet feedSet,
                                     Feed feed, String folderName,
                                     @Nullable SessionDataSource sessionDataSource) {
        Intent intent = new Intent(context, FeedItemsList.class);
        intent.putExtra(FeedItemsList.EXTRA_FEED, feed);
        intent.putExtra(FeedItemsList.EXTRA_FOLDER_NAME, folderName);
        intent.putExtra(ItemsList.EXTRA_FEED_SET, feedSet);
        intent.putExtra(ItemsList.EXTRA_SESSION_DATA, sessionDataSource);
        context.startActivity(intent);
    }

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
        setupFeedItems(getIntent());
        viewModel.getNextSession().observe(this, this::setupFeedItems);
        checkInAppReview();
    }

    @Override
    public void onBackPressed() {
        // see checkInAppReview()
        if (reviewInfo != null) {
            Task<Void> flow = reviewManager.launchReviewFlow(this, reviewInfo);
            flow.addOnCompleteListener(task -> {
                PrefsUtils.setInAppReviewed(this);
                super.onBackPressed();
            });
        } else {
            super.onBackPressed();
        }
    }

    public void deleteFeed() {
		DialogFragment deleteFeedFragment = DeleteFeedFragment.newInstance(feed, folderName);
		deleteFeedFragment.show(getSupportFragmentManager(), "dialog");
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		if (super.onOptionsItemSelected(item)) {
            return true;
        }
        if (item.getItemId() == R.id.menu_delete_feed) {
            deleteFeed();
            return true;
        }
        if (item.getItemId() == R.id.menu_notifications_disable) {
            feedUtils.disableNotifications(this, feed);
            return true;
        }
        if (item.getItemId() == R.id.menu_notifications_focus) {
            feedUtils.enableFocusNotifications(this, feed);
            return true;
        }
        if (item.getItemId() == R.id.menu_notifications_unread) {
            feedUtils.enableUnreadNotifications(this, feed);
            return true;
        }
        if (item.getItemId() == R.id.menu_instafetch_feed) {
            feedUtils.instaFetchFeed(this, feed.feedId);
            this.finish();
            return true;
        }
        if (item.getItemId() == R.id.menu_intel) {
            FeedIntelTrainerFragment intelFrag = FeedIntelTrainerFragment.newInstance(feed, fs);
            intelFrag.show(getSupportFragmentManager(), FeedIntelTrainerFragment.class.getName());
            return true;
        }
        if (item.getItemId() == R.id.menu_rename_feed) {
            RenameDialogFragment frag = RenameDialogFragment.newInstance(feed);
            frag.show(getSupportFragmentManager(), RenameDialogFragment.class.getName());
            return true;
            // TODO: since this activity uses a feed object passed as an extra and doesn't query the DB,
            // the name change won't be reflected until the activity finishes.
        }
        if (item.getItemId() == R.id.menu_statistics) {
            feedUtils.openStatistics(this, feed.feedId);
            return true;
        }
        return false;
	}

	@Override
	public boolean onPrepareOptionsMenu(Menu menu) {
		super.onPrepareOptionsMenu(menu);
        if (FeedExt.isAndroidNotifyUnread(feed)) {
            menu.findItem(R.id.menu_notifications_disable).setChecked(false);
            menu.findItem(R.id.menu_notifications_unread).setChecked(true);
            menu.findItem(R.id.menu_notifications_focus).setChecked(false);
        } else if (FeedExt.isAndroidNotifyFocus(feed)) {
            menu.findItem(R.id.menu_notifications_disable).setChecked(false);
            menu.findItem(R.id.menu_notifications_unread).setChecked(false);
            menu.findItem(R.id.menu_notifications_focus).setChecked(true);
        } else {
            menu.findItem(R.id.menu_notifications_disable).setChecked(true);
            menu.findItem(R.id.menu_notifications_unread).setChecked(false);
            menu.findItem(R.id.menu_notifications_focus).setChecked(false);
        }
		return true;
	}

    @Override
    String getSaveSearchFeedId() {
        return "feed:" + feed.feedId;
    }

    private void setupFeedItems(Session session) {
        Feed feed = session.getFeed();
        String folderName = session.getFolderName();
        if (feed != null && folderName != null) {
            setupFeedItems(feed, folderName);
        } else {
            finish();
        }
    }

    private void setupFeedItems(Intent intent) {
        Feed feed = (Feed) intent.getSerializableExtra(EXTRA_FEED);
        String folderName = intent.getStringExtra(EXTRA_FOLDER_NAME);
        setupFeedItems(feed, folderName);
    }

    private void setupFeedItems(@NonNull Feed feed, @NonNull String folderName) {
        this.feed = feed;
        this.folderName = folderName;
        UIUtils.setupToolbar(this, feed.faviconUrl, feed.title, iconLoader, false);
    }

    private void checkInAppReview() {
        if (!PrefsUtils.hasInAppReviewed(this)) {
            reviewManager = ReviewManagerFactory.create(this);
            Task<ReviewInfo> request = reviewManager.requestReviewFlow();
            request.addOnCompleteListener(task -> {
                if (task.isSuccessful()) {
                    reviewInfo = task.getResult();
                }
            });
        }
    }
}
