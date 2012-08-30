package com.newsblur.activity;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.FeedReadingAdapter;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.network.MarkStoryAsReadTask;
import com.newsblur.service.SyncService;
import com.newsblur.util.AppConstants;

public class FeedReading extends Reading {

	protected Set<String> storiesToMarkAsRead;
	String feedId;
	private Feed feed;
	private int currentPage;

	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);

		setResult(RESULT_OK);
		feedId = getIntent().getStringExtra(Reading.EXTRA_FEED);
		
		Uri classifierUri = FeedProvider.CLASSIFIER_URI.buildUpon().appendPath(feedId).build();
		Cursor feedClassifierCursor = contentResolver.query(classifierUri, null, null, null, null);
		Classifier classifier = Classifier.fromCursor(feedClassifierCursor);
		
		Uri storiesURI = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(feedId).build();
		storiesToMarkAsRead = new HashSet<String>();
		stories = contentResolver.query(storiesURI, null, FeedProvider.getSelectionFromState(currentState), null, DatabaseConstants.STORY_DATE + " DESC");

		final Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
		Cursor feedCursor = contentResolver.query(feedUri, null, null, null, null);

		feedCursor.moveToFirst();
		feed = Feed.fromCursor(feedCursor);
		setTitle(feed.title);

		readingAdapter = new FeedReadingAdapter(getSupportFragmentManager(), feed, stories);

		setupPager();

		Story story = readingAdapter.getStory(passedPosition);

		updateReadStories(story);
		
		syncFragment = (SyncUpdateFragment) fragmentManager.findFragmentByTag(SyncUpdateFragment.TAG);
		if (syncFragment == null) {
			syncFragment = new SyncUpdateFragment();
			fragmentManager.beginTransaction().add(syncFragment, SyncUpdateFragment.TAG).commit();
			triggerRefresh();
		}

	}

	private void updateReadStories(Story story) {
		storiesToMarkAsRead.add(readingAdapter.getStory(passedPosition).id);
		addStoryToMarkAsRead(story);
	}

	@Override
	public void onPageSelected(int position) {
		super.onPageSelected(position);
		if (readingAdapter.getStory(position) != null) {
			updateReadStories(readingAdapter.getStory(position));
			checkStoryCount(position);
		}
	}
	
	@Override
	public void checkStoryCount(int position) {
		if (position == stories.getCount() - 1) {
			boolean loadMore = false;

			switch (currentState) {
			case AppConstants.STATE_ALL:
				loadMore = feed.positiveCount + feed.neutralCount + feed.negativeCount > stories.getCount();
				break;
			case AppConstants.STATE_BEST:
				loadMore = feed.positiveCount > stories.getCount();
				break;
			case AppConstants.STATE_SOME:
				loadMore = feed.positiveCount + feed.neutralCount > stories.getCount();
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
	protected void onDestroy() {
		ArrayList<String> storyIds = new ArrayList<String>();
		storyIds.addAll(storiesToMarkAsRead);
		new MarkStoryAsReadTask(this, syncFragment, storyIds, feedId).execute();
		super.onDestroy();
	}

	@Override
	public void triggerRefresh() {
		triggerRefresh(0);
	}

	@Override
	public void triggerRefresh(int page) {
		setSupportProgressBarIndeterminateVisibility(true);
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, this, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, syncFragment.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_FEED_UPDATE);
		if (page > 1) {
			intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
		}
		intent.putExtra(SyncService.EXTRA_TASK_FEED_ID, feedId);
		startService(intent);
	}

	

}
