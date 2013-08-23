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

public class AllStoriesReading extends Reading {

	private int currentPage;
	private ArrayList<String> feedIds;
	private boolean stopLoading = false;
	private boolean requestedPage = false;

	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);

		setResult(RESULT_OK);

		StoryOrder storyOrder = PrefsUtils.getStoryOrderForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME);
		stories = contentResolver.query(FeedProvider.ALL_STORIES_URI, null, DatabaseConstants.getStorySelectionFromState(currentState), null, DatabaseConstants.getStorySortOrder(storyOrder));
		setTitle(getResources().getString(R.string.all_stories_row_title));
		readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), getContentResolver(), stories);

		setupPager();

        addStoryToMarkAsRead(readingAdapter.getStory(passedPosition));
	}
    
	@Override
	public void triggerRefresh() {
		triggerRefresh(1);
	}

	@Override
	public void checkStoryCount(int position) {
		if (position == stories.getCount() - 1 && !stopLoading && !requestedPage) {
			requestedPage = true;
			currentPage += 1;
			triggerRefresh(currentPage);
		}
	}

	@Override
	public void triggerRefresh(int page) {
		if (!stopLoading) {
			setSupportProgressBarIndeterminateVisibility(true);
			final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
			intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
			intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.MULTIFEED_UPDATE);

			intent.putExtra(SyncService.EXTRA_TASK_MULTIFEED_IDS, new String[0]); // ask for all stories via wildcarding the feed param
			if (page > 1) {
				intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
			}
			intent.putExtra(SyncService.EXTRA_TASK_ORDER, PrefsUtils.getStoryOrderForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME));
			intent.putExtra(SyncService.EXTRA_TASK_READ_FILTER, PrefsUtils.getReadFilterForFolder(this, PrefConstants.ALL_STORIES_FOLDER_NAME));

			startService(intent);
		}
	}

	@Override
	public void updateAfterSync() {
		requestedPage = false;
        super.updateAfterSync();
	}

	@Override
	public void setNothingMoreToUpdate() {
		stopLoading = true;
	}

	@Override
	public void closeAfterUpdate() { }

}
