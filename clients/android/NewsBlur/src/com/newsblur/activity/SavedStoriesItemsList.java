package com.newsblur.activity;

import java.util.ArrayList;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.app.FragmentTransaction;
import android.widget.Toast;

import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.fragment.SavedStoriesItemListFragment;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;

public class SavedStoriesItemsList extends ItemsList {

	private ContentResolver resolver;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

		setTitle(getResources().getString(R.string.saved_stories_title));

		resolver = getContentResolver();
		
		itemListFragment = (SavedStoriesItemListFragment) fragmentManager.findFragmentByTag(SavedStoriesItemListFragment.class.getName());
		if (itemListFragment == null) {
			itemListFragment = SavedStoriesItemListFragment.newInstance();
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, SavedStoriesItemListFragment.class.getName());
			listTransaction.commit();
		}

		syncFragment = (SyncUpdateFragment) fragmentManager.findFragmentByTag(SyncUpdateFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncUpdateFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncUpdateFragment.TAG).commit();
			triggerRefresh(1);
		}
	}

	@Override
	public void triggerRefresh(int page) {
		if (!stopLoading) {
			setSupportProgressBarIndeterminateVisibility(true);
			final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
			intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
			intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.STARRED_STORIES_UPDATE);
			intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
			startService(intent);
		}
	}


	@Override
	public void markItemListAsRead() {
        ; // This activity has no mark-as-read action
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		return false;
	}

    // Note: the following four methods are required by our parent spec but are not
    // relevant since saved stories have no read/unread status nor ordering.

    @Override
    protected StoryOrder getStoryOrder() {
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
}
