package com.newsblur.activity;

import android.os.Bundle;
import android.app.FragmentTransaction;
import android.view.Menu;
import android.view.MenuInflater;

import com.newsblur.R;
import com.newsblur.fragment.ReadStoriesItemListFragment;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.UIUtils;

public class ReadStoriesItemsList extends ItemsList {

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        UIUtils.setCustomActionBar(this, R.drawable.g_icn_unread_double, getResources().getString(R.string.read_stories_title));

		itemListFragment = (ReadStoriesItemListFragment) fragmentManager.findFragmentByTag(ReadStoriesItemListFragment.class.getName());
		if (itemListFragment == null) {
			itemListFragment = ReadStoriesItemListFragment.newInstance();
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, ReadStoriesItemListFragment.class.getName());
			listTransaction.commit();
		}
	}

	@Override
	public void markItemListAsRead() {
        ; // This activity has no mark-as-read action
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.readstories_itemslist, menu);
        return true;
	}

    @Override
    public void defaultFeedViewChanged(DefaultFeedView value) {
        PrefsUtils.setDefaultFeedViewForFolder(this, PrefConstants.READ_STORIES_FOLDER_NAME, value);
        if (itemListFragment != null) {
            itemListFragment.setDefaultFeedView(value);
        }
    }

    @Override
    protected void updateReadFilterPreference(ReadFilter newValue) {
        // dummy method.  read stories don't have an order option
    }
    
    @Override
    protected ReadFilter getReadFilter() {
        // dummy method. read stories always show reads and unreads
        return ReadFilter.ALL;
    }

}
