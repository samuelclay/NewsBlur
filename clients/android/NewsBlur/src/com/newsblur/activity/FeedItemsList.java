package com.newsblur.activity;

import android.os.Bundle;
import android.app.DialogFragment;
import android.app.FragmentTransaction;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;

import com.newsblur.R;
import com.newsblur.domain.Feed;
import com.newsblur.fragment.DeleteFeedFragment;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
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

		itemListFragment = (FeedItemListFragment) fragmentManager.findFragmentByTag(FeedItemListFragment.class.getName());
		if (itemListFragment == null) {
			itemListFragment = FeedItemListFragment.newInstance(feed);
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, FeedItemListFragment.class.getName());
			listTransaction.commit();
		}
	}

	public void deleteFeed() {
		DialogFragment deleteFeedFragment = DeleteFeedFragment.newInstance(feed, folderName);
		deleteFeedFragment.show(fragmentManager, "dialog");
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
        return false;
	}
	
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getMenuInflater();
		inflater.inflate(R.menu.feed_itemslist, menu);
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

    @Override
    protected void updateReadFilterPreference(ReadFilter newValue) {
        PrefsUtils.setReadFilterForFeed(this, feed.feedId, newValue);
    }
    
    @Override
    protected ReadFilter getReadFilter() {
        return PrefsUtils.getReadFilterForFeed(this, feed.feedId);
    }

}
