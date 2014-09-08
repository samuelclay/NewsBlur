package com.newsblur.activity;

import android.content.ContentValues;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.app.DialogFragment;
import android.app.FragmentTransaction;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Feed;
import com.newsblur.fragment.DeleteFeedFragment;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedSet;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;

public class FeedItemsList extends ItemsList {

	public static final String EXTRA_FEED = "feedId";
	public static final String EXTRA_FEED_TITLE = "feedTitle";
	public static final String EXTRA_FOLDER_NAME = "folderName";
	private String feedId;
	private String feedTitle;
	private String folderName;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

		feedId = getIntent().getStringExtra(EXTRA_FEED);
        feedTitle = getIntent().getStringExtra(EXTRA_FEED_TITLE);
        folderName = getIntent().getStringExtra(EXTRA_FOLDER_NAME);
        
		final Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
		Cursor cursor = getContentResolver().query(feedUri, null, DatabaseConstants.getStorySelectionFromState(currentState), null, null);
        if (cursor.getCount() > 0) {
            cursor.moveToFirst();
            Feed feed = Feed.fromCursor(cursor);
            setTitle(feed.title);
        }
        cursor.close();

		itemListFragment = (FeedItemListFragment) fragmentManager.findFragmentByTag(FeedItemListFragment.class.getName());
		if (itemListFragment == null) {
			itemListFragment = FeedItemListFragment.newInstance(feedId, currentState, getDefaultFeedView());
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, FeedItemListFragment.class.getName());
			listTransaction.commit();
		}
	}

    @Override
    protected FeedSet createFeedSet() {
        return FeedSet.singleFeed(getIntent().getStringExtra(EXTRA_FEED));
    }
	
	public void deleteFeed() {
		DialogFragment deleteFeedFragment = DeleteFeedFragment.newInstance(Long.parseLong(feedId), feedTitle, folderName);
		deleteFeedFragment.show(fragmentManager, "dialog");
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		if (!super.onOptionsItemSelected(item)) {
			if (item.getItemId() == R.id.menu_delete_feed) {
				deleteFeed();
				return true;
			} else {
				return false;
			}
		} else {
			return true;
		}
	}
	
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getMenuInflater();
		inflater.inflate(R.menu.feed_itemslist, menu);
		return true;
	}

    @Override
    protected StoryOrder getStoryOrder() {
        return PrefsUtils.getStoryOrderForFeed(this, feedId);
    }

    @Override
    public void updateStoryOrderPreference(StoryOrder newValue) {
        PrefsUtils.setStoryOrderForFeed(this, feedId, newValue);
    }
    
    @Override
    protected void updateReadFilterPreference(ReadFilter newValue) {
        PrefsUtils.setReadFilterForFeed(this, feedId, newValue);
    }
    
    @Override
    protected ReadFilter getReadFilter() {
        return PrefsUtils.getReadFilterForFeed(this, feedId);
    }

    @Override
    protected DefaultFeedView getDefaultFeedView() {
        return PrefsUtils.getDefaultFeedViewForFeed(this, feedId);
    }

    @Override
    public void defaultFeedViewChanged(DefaultFeedView value) {
        PrefsUtils.setDefaultFeedViewForFeed(this, feedId, value);
        if (itemListFragment != null) {
            itemListFragment.setDefaultFeedView(value);
        }
    }
}
