package com.newsblur.activity;

import java.util.ArrayList;

import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.app.FragmentTransaction;
import android.widget.Toast;

import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.fragment.FolderItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.network.APIManager;
import com.newsblur.network.MarkFolderAsReadTask;
import com.newsblur.service.SyncService;

public class FolderItemsList extends ItemsList {

	public static final String EXTRA_FOLDER_NAME = "folderName";
	private String folderName;
	private ArrayList<String> feedIds;
	private APIManager apiManager;
	private boolean stopLoading = false;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);
		folderName = getIntent().getStringExtra(EXTRA_FOLDER_NAME);

		setTitle(folderName);

		feedIds = new ArrayList<String>();

		apiManager = new APIManager(this);

		final Uri feedsUri = FeedProvider.FEED_FOLDER_MAP_URI.buildUpon().appendPath(folderName).build();
		Cursor cursor = getContentResolver().query(feedsUri, new String[] { DatabaseConstants.FEED_ID } , FeedProvider.getStorySelectionFromState(currentState), null, null);

		while (cursor.moveToNext()) {
			feedIds.add(cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_ID)));
		}

		itemListFragment = (FolderItemListFragment) fragmentManager.findFragmentByTag(FeedItemListFragment.FRAGMENT_TAG);
		if (itemListFragment == null) {
			itemListFragment = FolderItemListFragment.newInstance(feedIds, folderName, currentState);
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
	public boolean onCreateOptionsMenu(Menu menu) {
		MenuInflater inflater = getSupportMenuInflater();
		inflater.inflate(R.menu.itemslist, menu);
		return true;
	}

	@Override
	public void triggerRefresh(int page) {
		if (!stopLoading) {
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
	}


	@Override
	public void markItemListAsRead() {
		new MarkFolderAsReadTask(apiManager, getContentResolver()) {
			@Override
			protected void onPostExecute(Boolean result) {
				if (result) {
					setResult(RESULT_OK);
					Toast.makeText(FolderItemsList.this, R.string.toast_marked_folder_as_read, Toast.LENGTH_SHORT).show();
					finish();
				} else {
					Toast.makeText(FolderItemsList.this, R.string.toast_error_marking_feed_as_read, Toast.LENGTH_SHORT).show();
				}
			}
		}.execute(folderName);
	}


	@Override
	public void setNothingMoreToUpdate() {
		stopLoading = true;
	}
}
