package com.newsblur.activity;

import java.util.ArrayList;

import android.content.Intent;
import android.database.Cursor;
import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.service.SyncService;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.StoryOrder;

public class AllSharedStoriesReading extends Reading {

	private Cursor stories;
	private int currentPage;
	private ArrayList<String> feedIds;
	private boolean requestingPage = false;
	private boolean stopLoading = false;

	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);

		setResult(RESULT_OK);

		setupCountCursor();

		StoryOrder storyOrder = PrefsUtils.getStoryOrderForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME);
		stories = contentResolver.query(FeedProvider.ALL_SHARED_STORIES_URI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
		setTitle(getResources().getString(R.string.all_shared_stories));
		readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), getContentResolver(), stories);

		setupPager();

		addStoryToMarkAsRead(readingAdapter.getStory(passedPosition));
	}

	private void setupCountCursor() {
	    StoryOrder storyOrder = PrefsUtils.getStoryOrderForFolder(this, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME);
		Cursor cursor = getContentResolver().query(FeedProvider.FEEDS_URI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
		startManagingCursor(cursor);
		feedIds = new ArrayList<String>();
		while (cursor.moveToNext()) {
			feedIds.add(cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_ID)));
		}

	}

	@Override
	public void onPageSelected(int position) {
		super.onPageSelected(position);
		addStoryToMarkAsRead(readingAdapter.getStory(position));
		checkStoryCount(position);
	}

	@Override
	public void triggerRefresh() {
		triggerRefresh(1);
	}

	@Override
	public void checkStoryCount(int position) {
		if (position == stories.getCount() - 1 && !stopLoading && !requestingPage) {
			currentPage += 1;
			requestingPage = true;
			triggerRefresh(currentPage);
		}
	}

	@Override
	public void triggerRefresh(int page) {
		if (!stopLoading) {
			setSupportProgressBarIndeterminateVisibility(true);
			final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
			intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
			intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_MULTISOCIALFEED_UPDATE);

			String[] feeds = new String[feedIds.size()];
			feedIds.toArray(feeds);
			intent.putExtra(SyncService.EXTRA_TASK_MULTIFEED_IDS, feeds);
			if (page > 1) {
				intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
			}

			startService(intent);
		}
	}

	@Override
	public void updateAfterSync() {
		setSupportProgressBarIndeterminateVisibility(false);
		stories.requery();
		readingAdapter.notifyDataSetChanged();
		checkStoryCount(pager.getCurrentItem());
		requestingPage = false;
	}

	@Override
	public void setNothingMoreToUpdate() {
		stopLoading = true;
	}

	@Override
	public void closeAfterUpdate() { }

}
