package com.newsblur.activity;

import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.FragmentTransaction;
import android.util.Log;
import android.view.ContextMenu;
import android.view.View;
import android.view.ContextMenu.ContextMenuInfo;
import android.widget.Toast;

import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.actionbarsherlock.view.MenuItem;
import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Feed;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.network.APIManager;
import com.newsblur.network.MarkFeedAsReadTask;
import com.newsblur.service.SyncService;

public class FeedItemsList extends ItemsList {

	public static final String EXTRA_FEED = "feedId";
	private String feedId;
	private APIManager apiManager;
	private boolean stopLoading = false;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		apiManager = new APIManager(this);
		feedId = getIntent().getStringExtra(EXTRA_FEED);

		final Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
		Cursor cursor = getContentResolver().query(feedUri, null, FeedProvider.getStorySelectionFromState(currentState), null, null);
		cursor.moveToFirst();
		Feed feed = Feed.fromCursor(cursor);
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
	
	public void deleteFeed() {
		setSupportProgressBarIndeterminateVisibility(true);
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_DELETE_FEED);
		intent.putExtra(SyncService.EXTRA_TASK_FEED_ID, Long.parseLong(feedId));
		startService(intent);
	}

	@Override
	public boolean onOptionsItemSelected(MenuItem item) {
		if (!super.onOptionsItemSelected(item)) {
			switch (item.getItemId()) {
				case R.id.menu_delete_feed:
					deleteFeed();
					return true;
				default:
					return false;
			}
		} else {
			return true;
		}
	}
	
	@Override
	public void markItemListAsRead() {
		new MarkFeedAsReadTask(this, apiManager) {
			@Override
			protected void onPostExecute(Boolean result) {
				if (result.booleanValue()) {
					ContentValues values = new ContentValues();
					values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, 0);
					values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, 0);
					values.put(DatabaseConstants.FEED_POSITIVE_COUNT, 0);
					getContentResolver().update(FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build(), values, null, null);
					setResult(RESULT_OK);
					Toast.makeText(FeedItemsList.this, R.string.toast_marked_feed_as_read, Toast.LENGTH_LONG).show();
					finish();
				} else {
					Toast.makeText(FeedItemsList.this, R.string.toast_error_marking_feed_as_read, Toast.LENGTH_LONG).show();
				}
			}
		}.execute(feedId);
	}


	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getSupportMenuInflater();
		inflater.inflate(R.menu.feed_itemslist, menu);
		return true;
	}

	@Override
	public void triggerRefresh() {
		triggerRefresh(1);
	}

	@Override
	public void triggerRefresh(int page) {
		if (!stopLoading) {
			setSupportProgressBarIndeterminateVisibility(true);
			final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
			intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
			intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_FEED_UPDATE);
			intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
			intent.putExtra(SyncService.EXTRA_TASK_FEED_ID, feedId);
			startService(intent);
		}
	}

	@Override
	public void setNothingMoreToUpdate() {
		Log.d(TAG, "Stop loading");
		stopLoading = true;
	}

	@Override
	public void closeAfterUpdate() {
		finish();
	}


}