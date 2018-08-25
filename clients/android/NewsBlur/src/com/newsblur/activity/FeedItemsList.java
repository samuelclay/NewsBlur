package com.newsblur.activity;

import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.view.Menu;
import android.view.MenuItem;

import com.newsblur.R;
import com.newsblur.domain.Feed;
import com.newsblur.fragment.DeleteFeedFragment;
import com.newsblur.fragment.FeedIntelTrainerFragment;
import com.newsblur.fragment.RenameFeedFragment;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;

public class FeedItemsList extends ItemsList {

    public static final String EXTRA_FEED = "feed";
    public static final String EXTRA_FOLDER_NAME = "folderName";
	private Feed feed;
	private String folderName;

	@Override
	protected void onCreate(Bundle bundle) {
		feed = (Feed) getIntent().getSerializableExtra(EXTRA_FEED);
        folderName = getIntent().getStringExtra(EXTRA_FOLDER_NAME);
        
		super.onCreate(bundle);

        UIUtils.setCustomActionBar(this, feed.faviconUrl, feed.title);
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
            FeedUtils.disableNotifications(this, feed);
            return true;
        }
        if (item.getItemId() == R.id.menu_notifications_focus) {
            FeedUtils.enableFocusNotifications(this, feed);
            return true;
        }
        if (item.getItemId() == R.id.menu_notifications_unread) {
            FeedUtils.enableUnreadNotifications(this, feed);
            return true;
        }
        if (item.getItemId() == R.id.menu_instafetch_feed) {
            FeedUtils.instaFetchFeed(this, feed.feedId);
            this.finish();
            return true;
        }
        if (item.getItemId() == R.id.menu_intel) {
            FeedIntelTrainerFragment intelFrag = FeedIntelTrainerFragment.newInstance(feed, fs);
            intelFrag.show(getSupportFragmentManager(), FeedIntelTrainerFragment.class.getName());
            return true;
        }
        if (item.getItemId() == R.id.menu_rename_feed) {
            RenameFeedFragment frag = RenameFeedFragment.newInstance(feed);
            frag.show(getSupportFragmentManager(), RenameFeedFragment.class.getName());
            return true;
            // TODO: since this activity uses a feed object passed as an extra and doesn't query the DB,
            // the name change won't be reflected until the activity finishes.
        }
        return false;
	}
	
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
        if (!feed.active) {
            // there is currently no way for a feed to be un-muted while in this activity, so
            // don't bother creating the menu, which contains no valid options for a muted feed
            return false;
        }
		super.onCreateOptionsMenu(menu);
		return true;
	}

	@Override
	public boolean onPrepareOptionsMenu(Menu menu) {
		super.onPrepareOptionsMenu(menu);
        if (feed.isNotifyUnread()) {
            menu.findItem(R.id.menu_notifications_disable).setChecked(false);
            menu.findItem(R.id.menu_notifications_unread).setChecked(true);
            menu.findItem(R.id.menu_notifications_focus).setChecked(false);
        } else if (feed.isNotifyFocus()) {
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

}
