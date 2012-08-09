package com.newsblur.activity;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.FragmentTransaction;

import com.newsblur.R;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Feed;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;

public class FeedItemsList extends ItemsList {

	private String feedId;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		feedId = getIntent().getStringExtra(ItemsList.EXTRA_FEED);
		
		final Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
		Feed feed = Feed.fromCursor(getContentResolver().query(feedUri, null, FeedProvider.getSelectionFromState(currentState), null, null));
		setTitle(feed.title);
		
		itemListFragment = (FeedItemListFragment) fragmentManager.findFragmentByTag(FeedItemListFragment.FRAGMENT_TAG);
		if (itemListFragment == null) {
			itemListFragment = FeedItemListFragment.newInstance(feedId, currentState);
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
		setSupportProgressBarIndeterminateVisibility(true);
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_FEED_UPDATE);
		intent.putExtra(SyncService.EXTRA_TASK_FEED_ID, feedId);
		startService(intent);
	}


}