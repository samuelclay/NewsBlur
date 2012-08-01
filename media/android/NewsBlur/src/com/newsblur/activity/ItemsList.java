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
import com.newsblur.fragment.FeedIntelligenceSelectorFragment;
import com.newsblur.fragment.ItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public class ItemsList extends SherlockFragmentActivity implements SyncUpdateFragment.SyncUpdateFragmentInterface, StateChangedListener {

	public static final String EXTRA_FEED = "feedId";
	public static final String EXTRA_STATE = "currentIntelligenceState";
	private ItemListFragment itemListFragment;
	private FragmentManager fragmentManager;
	private SyncUpdateFragment syncFragment;
	private FeedIntelligenceSelectorFragment intelligenceSelectorFragment;
	private String feedId;
	private String TAG = "ItemsList";
	private int currentState;

	@Override
	protected void onCreate(Bundle bundle) {
		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(bundle);
		setContentView(R.layout.activity_itemslist);
		fragmentManager = getSupportFragmentManager();
		feedId = getIntent().getStringExtra(EXTRA_FEED);
		currentState = getIntent().getIntExtra(EXTRA_STATE, 0);

		getSupportActionBar().setDisplayHomeAsUpEnabled(true);

		final Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
		Feed feed = Feed.fromCursor(getContentResolver().query(feedUri, null, FeedProvider.getSelectionFromState(currentState), null, null));
		setTitle(feed.title);

		itemListFragment = (ItemListFragment) fragmentManager.findFragmentByTag(ItemListFragment.FRAGMENT_TAG);
		intelligenceSelectorFragment = (FeedIntelligenceSelectorFragment) fragmentManager.findFragmentByTag(FeedIntelligenceSelectorFragment.FRAGMENT_TAG);
		intelligenceSelectorFragment.setState(currentState);

		if (itemListFragment == null && feedId != null) {
			itemListFragment = ItemListFragment.newInstance(feedId, currentState);
			itemListFragment.setRetainInstance(true);
			FragmentTransaction listTransaction = fragmentManager.beginTransaction();
			listTransaction.add(R.id.activity_itemlist_container, itemListFragment, ItemListFragment.FRAGMENT_TAG);
			listTransaction.commit();
		}

		syncFragment = (SyncUpdateFragment) fragmentManager.findFragmentByTag(SyncUpdateFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncUpdateFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncUpdateFragment.TAG).commit();
			triggerRefresh();
		}
	}


	protected void onActivityResult(int requestCode, int resultCode, Intent data) {
		Log.d(TAG, "Returned okay.");
		if (resultCode == RESULT_OK) {
			itemListFragment.updated();
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