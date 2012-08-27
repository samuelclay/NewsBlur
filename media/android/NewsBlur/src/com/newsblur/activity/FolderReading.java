package com.newsblur.activity;

import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.MarkMixedStoriesAsReadTask;
import com.newsblur.service.SyncService;
import com.newsblur.util.AppConstants;

public class FolderReading extends Reading {
	protected ValueMultimap storiesToMarkAsRead;
	private String[] feedIds;
	private String folderName;
	private int positiveCount;
	private int negativeCount;
	private int neutralCount;
	private boolean requestedPage;
	private int currentPage;
	
	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);

		setResult(RESULT_OK);
		
		feedIds = getIntent().getStringArrayExtra(Reading.EXTRA_FEED_IDS);
		folderName = getIntent().getStringExtra(Reading.EXTRA_FOLDERNAME);
		setTitle(folderName);		
		
		Uri storiesURI = FeedProvider.MULTIFEED_STORIES_URI;
		storiesToMarkAsRead = new ValueMultimap();
		stories = contentResolver.query(storiesURI, null, FeedProvider.getSelectionFromState(currentState), feedIds, null);
		
		readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), stories);
		setupFolderCount();
		setupPager();
			
		storiesToMarkAsRead.put(readingAdapter.getStory(passedPosition).feedId, readingAdapter.getStory(passedPosition).id);
		addStoryToMarkAsRead(readingAdapter.getStory(passedPosition));
	}
	
	@Override
	public void onPageSelected(int position) {
		storiesToMarkAsRead.put(readingAdapter.getStory(position).feedId, readingAdapter.getStory(position).id);
		addStoryToMarkAsRead(readingAdapter.getStory(position));
		checkStoryCount(position);
		super.onPageSelected(position);
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
	
	private void setupFolderCount() {
		
		Uri individualFolderUri = FeedProvider.FOLDERS_URI.buildUpon().appendPath(folderName).build();
		Cursor folderCursor = contentResolver.query(individualFolderUri, null, null, null, null);
		folderCursor.moveToFirst();
		positiveCount = folderCursor.getInt(folderCursor.getColumnIndex(DatabaseConstants.SUM_POS));
		negativeCount = folderCursor.getInt(folderCursor.getColumnIndex(DatabaseConstants.SUM_NEG));
		neutralCount = folderCursor.getInt(folderCursor.getColumnIndex(DatabaseConstants.SUM_NEUT));
	}

	@Override
	public void triggerRefresh(int page) {
		setSupportProgressBarIndeterminateVisibility(true);
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_MULTIFEED_UPDATE);
		intent.putExtra(SyncService.EXTRA_TASK_MULTIFEED_IDS, feedIds);
		if (page > 1) {
			intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
		}

		startService(intent);
	}

	@Override
	public void updateAfterSync() {
		setSupportProgressBarIndeterminateVisibility(false);
		stories.requery();
		requestedPage = false;
		readingAdapter.notifyDataSetChanged();
		checkStoryCount(pager.getCurrentItem());
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
	
			if (loadMore && !requestedPage) {
				currentPage += 1;
				requestedPage = true;
				triggerRefresh(currentPage);
			} else {
				Log.d(TAG, "No need");
			}
		}
	}

}
