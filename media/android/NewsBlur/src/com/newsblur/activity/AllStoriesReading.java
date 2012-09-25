package com.newsblur.activity;

import java.util.ArrayList;

import android.content.ContentProviderOperation;
import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;
import android.util.Log;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.MarkMixedStoriesAsReadTask;
import com.newsblur.service.SyncService;
import com.newsblur.util.AppConstants;

public class AllStoriesReading extends Reading {
	
	private Cursor stories;
	private ValueMultimap storiesToMarkAsRead;
	private int negativeCount;
	private int neutralCount;
	private int positiveCount;
	private int currentPage;
	private ArrayList<String> feedIds;
	
	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);
		
		setResult(RESULT_OK);
		
		setupCountCursor();
		
		stories = contentResolver.query(FeedProvider.ALL_STORIES_URI, null, FeedProvider.getStorySelectionFromState(currentState), null, null);
		setTitle(getResources().getString(R.string.all_stories));
		storiesToMarkAsRead = new ValueMultimap();
		readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), getContentResolver(), stories);

		setupPager();
		
		addStoryToMarkAsRead(readingAdapter.getStory(passedPosition));
		storiesToMarkAsRead.put(readingAdapter.getStory(passedPosition).feedId, readingAdapter.getStory(passedPosition).id);
	}

	private void setupCountCursor() {
		Cursor countCursor = contentResolver.query(FeedProvider.FEED_COUNT_URI, null, DatabaseConstants.SOCIAL_INTELLIGENCE_SOME, null, null);
		countCursor.moveToFirst();
		negativeCount = countCursor.getInt(countCursor.getColumnIndex(DatabaseConstants.SUM_NEG));
		neutralCount = countCursor.getInt(countCursor.getColumnIndex(DatabaseConstants.SUM_NEUT));
		positiveCount = countCursor.getInt(countCursor.getColumnIndex(DatabaseConstants.SUM_POS));
		
		Cursor cursor = getContentResolver().query(FeedProvider.FEEDS_URI, null, FeedProvider.getStorySelectionFromState(currentState), null, null);
		feedIds = new ArrayList<String>();
		while (cursor.moveToNext()) {
			feedIds.add(cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_ID)));
		}
		
	}
	
	@Override
	public void onPageSelected(int position) {
		super.onPageSelected(position);
		storiesToMarkAsRead.put(readingAdapter.getStory(position).feedId, readingAdapter.getStory(position).id);
		addStoryToMarkAsRead(readingAdapter.getStory(position));
		checkStoryCount(position);
	}
	
	@Override
	protected void onDestroy() {
		new MarkMixedStoriesAsReadTask(this, syncFragment, storiesToMarkAsRead).execute();
		super.onDestroy();
	}

	@Override
	public void triggerRefresh() {
		triggerRefresh(1);
	}
	
	@Override
	public void checkStoryCount(int position) {
		if (position == stories.getCount() - 1) {
			boolean loadMore = false;

			switch (currentState) {
			case AppConstants.STATE_ALL:
				loadMore = positiveCount + neutralCount + negativeCount > stories.getCount();
				break;
			case AppConstants.STATE_BEST:
				loadMore = positiveCount > stories.getCount();
				break;
			case AppConstants.STATE_SOME:
				loadMore = positiveCount + neutralCount > stories.getCount();
				break;	
			}

			if (loadMore) {
				currentPage += 1;
				triggerRefresh(currentPage);
			} else {
				Log.d(TAG, "No need");
			}
		}
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
		if (page > 1) {
			intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
		}

		startService(intent);
	}

	@Override
	public void updateAfterSync() {
		setSupportProgressBarIndeterminateVisibility(false);
		stories.requery();
		readingAdapter.notifyDataSetChanged();
		checkStoryCount(pager.getCurrentItem());
	}
	
}
