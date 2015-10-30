package com.newsblur.activity;

import android.os.Bundle;
import android.app.FragmentTransaction;
import android.util.Log;
import android.view.Menu;
import android.view.MenuInflater;

import com.newsblur.R;
import com.newsblur.fragment.AllStoriesItemListFragment;
import com.newsblur.fragment.MarkAllReadDialogFragment;
import com.newsblur.fragment.MarkAllReadDialogFragment.MarkAllReadDialogListener;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.FeedSet;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.util.UIUtils;

public class AllStoriesItemsList extends ItemsList implements MarkAllReadDialogListener {

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        UIUtils.setCustomActionBar(this, R.drawable.ak_icon_allstories, getResources().getString(R.string.all_stories));

		itemListFragment = (AllStoriesItemListFragment) fragmentManager.findFragmentByTag(AllStoriesItemListFragment.class.getName());
		if (itemListFragment == null) {
			itemListFragment = AllStoriesItemListFragment.newInstance();
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, AllStoriesItemListFragment.class.getName());
			listTransaction.commit();
		}
	}

	@Override
    protected FeedSet createFeedSet() {
        return FeedSet.allFeeds();
    }
    
	@Override
	public void markItemListAsRead() {
	    MarkAllReadDialogFragment dialog = MarkAllReadDialogFragment.newInstance(getResources().getString(R.string.all_stories));
        dialog.show(fragmentManager, "dialog");
	}

    @Override
    public void onMarkAllRead() {
        super.markItemListAsRead();
    }

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getMenuInflater();
		inflater.inflate(R.menu.allstories_itemslist, menu);
		return true;
	}

    @Override
    public StoryOrder getStoryOrder() {
        return PrefsUtils.getStoryOrderForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME);
    }

    @Override
    public void updateStoryOrderPreference(StoryOrder newValue) {
        PrefsUtils.setStoryOrderForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME, newValue);
    }
    
    @Override
    protected void updateReadFilterPreference(ReadFilter newValue) {
        PrefsUtils.setReadFilterForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME, newValue);
    }
    
    @Override
    protected ReadFilter getReadFilter() {
        return PrefsUtils.getReadFilterForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME);
    }

    @Override
    public void defaultFeedViewChanged(DefaultFeedView value) {
        PrefsUtils.setDefaultFeedViewForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME, value);
        if (itemListFragment != null) {
            itemListFragment.setDefaultFeedView(value);
        }
    }

    @Override
    public void onCancel() {
        // do nothing
    }

}
