package com.newsblur.activity;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.Fragment;
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
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.fragment.ItemListFragment;
import com.newsblur.fragment.SocialFeedItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;
import com.newsblur.view.StateToggleButton.StateChangedListener;

public class ItemsList extends SherlockFragmentActivity implements SyncUpdateFragment.SyncUpdateFragmentInterface, StateChangedListener {

	public static final String EXTRA_FEED = "feedId";
	public static final String EXTRA_STATE = "currentIntelligenceState";
	public static final String EXTRA_BLURBLOG_USERNAME = "blurblogName";
	public static final String EXTRA_BLURBLOG_USERID = "blurblogId";
	private ItemListFragment itemListFragment;
	private FragmentManager fragmentManager;
	private SyncUpdateFragment syncFragment;
	private FeedIntelligenceSelectorFragment intelligenceSelectorFragment;
	private String feedId, userId, username;
	private String TAG = "ItemsList";
	private int currentState;

	@Override
	protected void onCreate(Bundle bundle) {
		requestWindowFeature(Window.FEATURE_PROGRESS);
		requestWindowFeature(Window.FEATURE_INDETERMINATE_PROGRESS);
		super.onCreate(bundle);
		setResult(RESULT_OK);
		
		setContentView(R.layout.activity_itemslist);
		fragmentManager = getSupportFragmentManager();

		if ((feedId = getIntent().getStringExtra(EXTRA_FEED)) != null) {
			// Specific feed 
			final Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
			Feed feed = Feed.fromCursor(getContentResolver().query(feedUri, null, FeedProvider.getSelectionFromState(currentState), null, null));
			setTitle(feed.title);
		} else {
			// Blurblog
			username = getIntent().getStringExtra(EXTRA_BLURBLOG_USERNAME);
			userId = getIntent().getStringExtra(EXTRA_BLURBLOG_USERID);
			setTitle(username);
		}

		currentState = getIntent().getIntExtra(EXTRA_STATE, 0);
		getSupportActionBar().setDisplayHomeAsUpEnabled(true);
		
		itemListFragment = (FeedItemListFragment) fragmentManager.findFragmentByTag(FeedItemListFragment.FRAGMENT_TAG);
		intelligenceSelectorFragment = (FeedIntelligenceSelectorFragment) fragmentManager.findFragmentByTag(FeedIntelligenceSelectorFragment.FRAGMENT_TAG);
		intelligenceSelectorFragment.setState(currentState);

		if (itemListFragment == null) {
			if (feedId != null) {
				itemListFragment = FeedItemListFragment.newInstance(feedId, currentState);
			} else {
				itemListFragment = SocialFeedItemListFragment.newInstance(userId, username, currentState);
			}
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


	protected void onActivityResult(int requestCode, int resultCode, Intent data) {
		Log.d(TAG, "Returned okay.");
		if (resultCode == RESULT_OK) {
			itemListFragment.hasUpdated();
		}
	}


	public void triggerRefresh() {
		setSupportProgressBarIndeterminateVisibility(true);
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		if (feedId != null) {
			intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_FEED_UPDATE);
			intent.putExtra(SyncService.EXTRA_TASK_FEED_ID, feedId);
		} else {
			intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_SOCIALFEED_UPDATE);
			intent.putExtra(SyncService.EXTRA_TASK_SOCIALFEED_ID, userId);
			intent.putExtra(SyncService.EXTRA_TASK_SOCIALFEED_USERNAME, username);
		}
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
		if (itemListFragment != null) {
			itemListFragment.hasUpdated();
		}
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