package com.newsblur.activity;

import java.util.ArrayList;

import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.support.v4.app.FragmentTransaction;

import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.fragment.AllSharedStoriesItemListFragment;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;

public class AllSharedStoriesItemsList extends ItemsList {

	private ArrayList<String> feedIds;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

		setTitle(getResources().getString(R.string.all_shared_stories));

		feedIds = new ArrayList<String>();

		Cursor cursor = getContentResolver().query(FeedProvider.SOCIAL_FEEDS_URI, null, null, null, null);
		while (cursor.moveToNext()) {
			feedIds.add(cursor.getString(cursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_ID)));
		}
		cursor.close();

		itemListFragment = (AllSharedStoriesItemListFragment) fragmentManager.findFragmentByTag(AllSharedStoriesItemListFragment.class.getName());
		if (itemListFragment == null) {
			itemListFragment = AllSharedStoriesItemListFragment.newInstance(currentState, getStoryOrder(), getDefaultFeedView());
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, AllSharedStoriesItemListFragment.class.getName());
			listTransaction.commit();
		}
	}

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = getSupportMenuInflater();
        inflater.inflate(R.menu.allsocialstories_itemslist, menu);
        return true;
    }

	@Override
	public void triggerRefresh(int page) {
		if (!stopLoading) {
			setSupportProgressBarIndeterminateVisibility(true);
			String[] feeds = new String[feedIds.size()];
			feedIds.toArray(feeds);
            FeedUtils.updateSocialFeeds(this, this, feeds, page, getStoryOrder(), PrefsUtils.getReadFilterForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME));
		}
	}

	// We don't allow All Shared Stories to be marked as read
	@Override
	public void markItemListAsRead() { }

    @Override
    protected StoryOrder getStoryOrder() {
        return PrefsUtils.getStoryOrderForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME);
    }

    @Override
    public void updateStoryOrderPreference(StoryOrder newValue) {
        PrefsUtils.setStoryOrderForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME, newValue);
    }

    @Override
    protected void updateReadFilterPreference(ReadFilter newValue) {
        PrefsUtils.setReadFilterForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME, newValue);
    }
    
    @Override
    protected ReadFilter getReadFilter() {
        return PrefsUtils.getReadFilterForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME);
    }

    @Override
    protected DefaultFeedView getDefaultFeedView() {
        return PrefsUtils.getDefaultFeedViewForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME);
    }

    @Override
    public void defaultFeedViewChanged(DefaultFeedView value) {
        PrefsUtils.setDefaultFeedViewForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME, value);
        if (itemListFragment != null) {
            itemListFragment.setDefaultFeedView(value);
        }
    }
}
