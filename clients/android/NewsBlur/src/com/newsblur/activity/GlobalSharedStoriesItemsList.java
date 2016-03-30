package com.newsblur.activity;

import android.app.FragmentTransaction;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuInflater;

import com.newsblur.R;
import com.newsblur.fragment.GlobalSharedStoriesItemListFragment;
import com.newsblur.util.DefaultFeedView;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.UIUtils;

public class GlobalSharedStoriesItemsList extends ItemsList {

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

        UIUtils.setCustomActionBar(this, R.drawable.ak_icon_global, getResources().getString(R.string.global_shared_stories));

		itemListFragment = (GlobalSharedStoriesItemListFragment) fragmentManager.findFragmentByTag(GlobalSharedStoriesItemListFragment.class.getName());
		if (itemListFragment == null) {
			itemListFragment = GlobalSharedStoriesItemListFragment.newInstance();
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, GlobalSharedStoriesItemListFragment.class.getName());
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
        inflater.inflate(R.menu.allsocialstories_itemslist, menu);
        return true;
	}

    @Override
    public void defaultFeedViewChanged(DefaultFeedView value) {
        PrefsUtils.setDefaultFeedViewForFolder(this, PrefConstants.GLOBAL_SHARED_STORIES_FOLDER_NAME, value);
        if (itemListFragment != null) {
            itemListFragment.setDefaultFeedView(value);
        }
    }

    @Override
    protected void updateReadFilterPreference(ReadFilter newValue) {
        // Not supported for global shared stories
    }
    
    @Override
    protected ReadFilter getReadFilter() {
        return ReadFilter.UNREAD;
    }

}
