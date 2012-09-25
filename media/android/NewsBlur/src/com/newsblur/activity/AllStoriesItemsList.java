package com.newsblur.activity;

import java.util.ArrayList;

import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.support.v4.app.FragmentTransaction;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.fragment.AllStoriesItemListFragment;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;

public class AllStoriesItemsList extends ItemsList {

	private ArrayList<String> feedIds;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		
		setTitle(getResources().getString(R.string.all_stories));
		
		feedIds = new ArrayList<String>();
		
		Cursor cursor = getContentResolver().query(FeedProvider.FEEDS_URI, null, FeedProvider.getStorySelectionFromState(currentState), null, null);
		
		while (cursor.moveToNext()) {
			feedIds.add(cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_ID)));
		}
		
		itemListFragment = (AllStoriesItemListFragment) fragmentManager.findFragmentByTag(FeedItemListFragment.FRAGMENT_TAG);
		if (itemListFragment == null) {
			itemListFragment = AllStoriesItemListFragment.newInstance(currentState);
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, FeedItemListFragment.FRAGMENT_TAG);
			listTransaction.commit();
		}
		
		syncFragment = (SyncUpdateFragment) fragmentManager.findFragmentByTag(SyncUpdateFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncUpdateFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncUpdateFragment.TAG).commit();
			triggerRefresh();
		}
	}


	@Override
	public void triggerRefresh() {
		triggerRefresh(1);
	}

	@Override
	public void triggerRefresh(int page) {
		setSupportProgressBarIndeterminateVisibility(true);
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_MULTIFEED_UPDATE);
		
		String[] feeds = new String[feedIds.size()];
		feedIds.toArray(feeds);
		intent.putExtra(SyncService.EXTRA_TASK_MULTIFEED_IDS, feeds);
		intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));

		startService(intent);
	}


	@Override
	public void markItemListAsRead() {
		// TODO Auto-generated method stub
		
	}
	
}
