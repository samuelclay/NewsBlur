package com.newsblur.activity;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;
import android.util.Log;

import com.actionbarsherlock.app.SherlockFragmentActivity;
import com.actionbarsherlock.view.MenuItem;
import com.newsblur.R;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.fragment.ItemListFragment;
import com.newsblur.service.DetachableResultReceiver;
import com.newsblur.service.DetachableResultReceiver.Receiver;
import com.newsblur.service.SyncService;

public class ItemsList extends SherlockFragmentActivity {

	public static final String EXTRA_FEED = "feedId";
	private ItemListFragment itemListFragment;
	private FragmentManager fragmentManager;
	private final String FRAGMENT_TAG = "itemListFragment";
	private SyncReadingUpdaterFragment syncFragment;
	private String feedId;
	private String TAG = "ItemsList";

	@Override
	protected void onCreate(Bundle bundle) {
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

		syncFragment = (SyncReadingUpdaterFragment) fragmentManager.findFragmentByTag(SyncReadingUpdaterFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncReadingUpdaterFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncReadingUpdaterFragment.TAG).commit();
			triggerRefresh();
		}
	}

	public void redrawUI() {
		Log.d(TAG , "Redrawing UI");
		itemListFragment.updated();
	}

	public void triggerRefresh() {
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_FEED_UPDATE);
		intent.putExtra(SyncService.EXTRA_TASK_FEED_ID, feedId);
		startService(intent);
	}

	public static class SyncReadingUpdaterFragment extends Fragment implements Receiver {
		public static final String TAG = "SyncReadingFragment";
		private DetachableResultReceiver receiver;

		public SyncReadingUpdaterFragment() {
			receiver = new DetachableResultReceiver(new Handler());
			receiver.setReceiver(this);
		}

		@Override
		public void onCreate(Bundle savedInstanceState) {
			super.onCreate(savedInstanceState);
			setRetainInstance(true);
			Log.d(TAG, "Creating syncfragment");
		}

		@Override
		public void onAttach(Activity activity) {
			super.onAttach(activity);
			Log.d(TAG, "Attached");
		}

		@Override
		public void onReceiverResult(int resultCode, Bundle resultData) {
			switch (resultCode) {
			case SyncService.STATUS_FINISHED:
				Log.d(TAG, "Synchronisation finished.");
				if (getActivity() != null) {
					((ItemsList) getActivity()).redrawUI();
				}
				break;
			case SyncService.STATUS_RUNNING:
				Log.d(TAG, "Synchronisation running.");
				break;		
			default:
				Log.e(TAG, "Unrecognised response attempting to get reading data");
				break;
			}
		}
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

}