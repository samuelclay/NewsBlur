package com.newsblur.activity;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Set;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.Story;
import com.newsblur.network.MarkSocialStoryAsReadTask;
import com.newsblur.service.SyncService;
import com.newsblur.util.AppConstants;

public class SocialFeedReading extends Reading {
	
	MarkSocialAsReadUpdate markSocialAsReadList;
	private String userId;
	private String username;
	private SocialFeed socialFeed;
	private boolean requestedPage;
	private int currentPage;
	
	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);
		
		setResult(RESULT_OK);
		
		userId = getIntent().getStringExtra(Reading.EXTRA_USERID);
		username = getIntent().getStringExtra(Reading.EXTRA_USERNAME);
		markSocialAsReadList = new MarkSocialAsReadUpdate(userId);
		
		Uri socialFeedUri = FeedProvider.SOCIAL_FEEDS_URI.buildUpon().appendPath(userId).build();
		socialFeed = SocialFeed.fromCursor(contentResolver.query(socialFeedUri, null, null, null, null));
		
		Uri storiesURI = FeedProvider.SOCIALFEED_STORIES_URI.buildUpon().appendPath(userId).build();
		stories = contentResolver.query(storiesURI, null, FeedProvider.getStorySelectionFromState(currentState), null, null);
		setTitle(getIntent().getStringExtra(EXTRA_USERNAME));

		readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), getContentResolver(), stories);

		setupPager();

		Story story = readingAdapter.getStory(passedPosition);
		markSocialAsReadList.add(story.feedId, story.id);
		addStoryToMarkAsRead(story);
		
	}
	
	@Override
	public void onPageSelected(int position) {
		super.onPageSelected(position);
		Story story = readingAdapter.getStory(position);
		if (story != null) {
			markSocialAsReadList.add(story.feedId, story.id);
			addStoryToMarkAsRead(story);
		}
		checkStoryCount(position);
	}

	@Override
	protected void onDestroy() {
		new MarkSocialStoryAsReadTask(this, syncFragment, markSocialAsReadList).execute();
		super.onDestroy();
	}
	
	public class MarkSocialAsReadUpdate {
		public String userId;
		HashMap<String, Set<String>> feedStoryMap;
		
		public MarkSocialAsReadUpdate(final String userId) {
			this.userId = userId;
			feedStoryMap = new HashMap<String, Set<String>>();
		}
		
		public void add(final String feedId, final String storyId) {
			if (feedStoryMap.get(feedId) == null) {
				Set<String> storiesForFeed = new HashSet<String>();
				storiesForFeed.add(storyId);
				feedStoryMap.put(feedId, storiesForFeed);
			} else {
				feedStoryMap.get(feedId).add(storyId);
			}
		}
		
		public Object getJsonObject() {
			HashMap<String, HashMap<String, Set<String>>> jsonMap = new HashMap<String, HashMap<String, Set<String>>>();
			jsonMap.put(userId, feedStoryMap);
			return jsonMap;
		}
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
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_SOCIALFEED_UPDATE);
		intent.putExtra(SyncService.EXTRA_TASK_SOCIALFEED_ID, userId);
		if (page > 1) {
			intent.putExtra(SyncService.EXTRA_TASK_PAGE_NUMBER, Integer.toString(page));
		}
		intent.putExtra(SyncService.EXTRA_TASK_SOCIALFEED_USERNAME, username);
		startService(intent);
	}


	@Override
	public void checkStoryCount(int position) {
		if (position == stories.getCount() - 1) {
			boolean loadMore = false;
			
			switch (currentState) {
			case AppConstants.STATE_ALL:
				loadMore = socialFeed.positiveCount + socialFeed.neutralCount + socialFeed.negativeCount > stories.getCount();
				break;
			case AppConstants.STATE_BEST:
				loadMore = socialFeed.positiveCount > stories.getCount();
				break;
			case AppConstants.STATE_SOME:
				loadMore = socialFeed.positiveCount + socialFeed.neutralCount > stories.getCount();
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
