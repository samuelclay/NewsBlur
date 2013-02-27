package com.newsblur.activity;

import java.util.ArrayList;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.support.v4.app.FragmentTransaction;
import android.widget.Toast;

import com.actionbarsherlock.view.Menu;
import com.actionbarsherlock.view.MenuInflater;
import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Story;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.fragment.AllStoriesItemListFragment;
import com.newsblur.fragment.FeedItemListFragment;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.network.APIManager;
import com.newsblur.network.MarkAllStoriesAsReadTask;
import com.newsblur.service.SyncService;

public class AllStoriesItemsList extends ItemsList {

	private ArrayList<String> feedIds;
	private APIManager apiManager;
	private ContentResolver resolver;
	private boolean stopLoading = false;

	@Override
	protected void onCreate(Bundle bundle) {
		super.onCreate(bundle);

		setTitle(getResources().getString(R.string.all_stories));

		feedIds = new ArrayList<String>();
		apiManager = new APIManager(this);
		resolver = getContentResolver();
		
		Cursor cursor = resolver.query(FeedProvider.FEEDS_URI, null, FeedProvider.getStorySelectionFromState(currentState), null, null);

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
		Cursor stories = getContentResolver().query(FeedProvider.ALL_STORIES_URI, null, FeedProvider.getStorySelectionFromState(currentState), null, null);
		ValueMultimap storiesToMarkAsRead = new ValueMultimap();
		for (int i = 0; i < stories.getCount(); i++) {
	      stories.moveToNext();
		  Story story = Story.fromCursor(stories);
		  storiesToMarkAsRead.put(story.feedId, story.id);
		}
		
		new MarkAllStoriesAsReadTask(apiManager) {
			@Override
			protected void onPostExecute(Boolean result) {
				if (result) {
					// mark all feed IDs as read
					ContentValues values = new ContentValues();
					values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, 0);
					values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, 0);
					values.put(DatabaseConstants.FEED_POSITIVE_COUNT, 0);
					for (String feedId : feedIds) {
						resolver.update(FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build(), values, null, null);
					}
					setResult(RESULT_OK); 
					Toast.makeText(AllStoriesItemsList.this, R.string.toast_marked_all_stories_as_read, Toast.LENGTH_SHORT).show();
					finish();
				} else {
					Toast.makeText(AllStoriesItemsList.this, R.string.toast_error_marking_feed_as_read, Toast.LENGTH_SHORT).show();
				}
			}
		}.execute(storiesToMarkAsRead);
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		super.onCreateOptionsMenu(menu);
		MenuInflater inflater = getSupportMenuInflater();
		inflater.inflate(R.menu.allstories_itemslist, menu);
		return true;
	}

	@Override
	public void setNothingMoreToUpdate() {
		stopLoading = true;
	}


	@Override
	public void closeAfterUpdate() { }

}
