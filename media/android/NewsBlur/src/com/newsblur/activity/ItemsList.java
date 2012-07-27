package com.newsblur.activity;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;
import android.util.Log;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.actionbarsherlock.view.MenuItem;
import com.actionbarsherlock.view.Window;
import com.newsblur.R;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Feed;
import com.newsblur.fragment.ItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public class ItemsList extends SherlockFragmentActivity implements SyncUpdateFragment.SyncUpdateFragmentInterface, StateChangedListener {

	public static final String EXTRA_FEED = "feedId";
	private ItemListFragment itemListFragment;
	private FragmentManager fragmentManager;
	private final String FRAGMENT_TAG = "itemListFragment";
	private SyncUpdateFragment syncFragment;
	private String feedId;
	private String TAG = "ItemsList";

	@Override
	protected void onCreate(Bundle bundle) {
		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(bundle);
		setContentView(R.layout.activity_itemslist);
		fragmentManager = getSupportFragmentManager();
		feedId = getIntent().getStringExtra(EXTRA_FEED);

		getSupportActionBar().setDisplayHomeAsUpEnabled(true);

		final Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
		Feed feed = Feed.fromCursor(getContentResolver().query(feedUri, null, null, null, null));
		setTitle(feed.title);

		itemListFragment = (ItemListFragment) fragmentManager.findFragmentByTag(FRAGMENT_TAG);

		if (itemListFragment == null && feedId != null) {
			itemListFragment = ItemListFragment.newInstance(feedId);
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, FRAGMENT_TAG);
			listTransaction.commit();
		}

		syncFragment = (SyncUpdateFragment) fragmentManager.findFragmentByTag(SyncUpdateFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncUpdateFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncUpdateFragment.TAG).commit();
			triggerRefresh();
		}
	}

	public void triggerRefresh() {
		setSupportProgressBarIndeterminateVisibility(true);
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_FEED_UPDATE);
		intent.putExtra(SyncService.EXTRA_TASK_FEED_ID, feedId);
		startService(intent);
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		switch (item.getItemId()) {
		case android.R.id.home:
			finish();
			return true;
		}
		return false;
	}

	@Override
	public void updateAfterSync() {
		Log.d(TAG , "Redrawing UI");
		itemListFragment.updated();
		setSupportProgressBarIndeterminateVisibility(false);
	}

	@Override
	public void updateSyncStatus(boolean syncRunning) {
		if (syncRunning) {
			setSupportProgressBarIndeterminateVisibility(true);
		}
	}

	@Override
	public void changedState(int state) {
		Log.d(TAG, "Changed state.");
		itemListFragment.changeState(state);
	}

}