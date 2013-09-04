package com.newsblur.activity;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.service.SyncService;
import com.newsblur.util.PrefsUtils;

public class FolderReading extends Reading {

	private String[] feedIds;
	private String folderName;
	private boolean stopLoading = false;
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
		stories = contentResolver.query(storiesURI, null, DatabaseConstants.getStorySelectionFromState(currentState), feedIds, null);

		readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), getContentResolver(), stories);
		setupPager();

		addStoryToMarkAsRead(readingAdapter.getStory(passedPosition));
	}

	@Override
	public void triggerRefresh() {
		triggerRefresh(1);
	}

	@Override
	public void triggerRefresh(int page) {
		setSupportProgressBarIndeterminateVisibility(true);
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.EXTRA_TASK_TYPE, SyncService.TaskType.MULTIFEED_UPDATE);
		intent.putExtra(SyncService.EXTRA_TASK_MULTIFEED_IDS, feedIds);
		
		if (page > 1) {
			intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
		}
        intent.putExtra(SyncService.EXTRA_TASK_ORDER, PrefsUtils.getStoryOrderForFolder(this, folderName));
        intent.putExtra(SyncService.EXTRA_TASK_READ_FILTER, PrefsUtils.getReadFilterForFolder(this, folderName));
        
		startService(intent);
	}

	@Override
	public void updateAfterSync() {
		requestedPage = false;
        super.updateAfterSync();
	}

	@Override
	public void checkStoryCount(int position) {
		if (position == stories.getCount() - 1 && !stopLoading && !requestedPage) {
			currentPage += 1;
			requestedPage = true;
			triggerRefresh(currentPage);
		}
	}

	@Override
	public void setNothingMoreToUpdate() {
		stopLoading = true;
	}

	@Override
	public void closeAfterUpdate() { }

}
