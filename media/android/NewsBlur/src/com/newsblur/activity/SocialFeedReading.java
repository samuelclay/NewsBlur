package com.newsblur.activity;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Set;

import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;

import com.newsblur.database.FeedProvider;
import com.newsblur.database.MarkStoryAsReadIntenallyTask;
import com.newsblur.domain.Story;
import com.newsblur.network.MarkSocialStoryAsReadTask;

public class SocialFeedReading extends Reading {
	
	private Cursor stories;
	MarkSocialAsReadUpdate markSocialAsReadList;
	
	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);
		
		String userId = getIntent().getStringExtra(Reading.EXTRA_USERID);
		
		Uri storiesURI = FeedProvider.SOCIAL_FEEDS_URI.buildUpon().appendPath(userId).build();
		stories = contentResolver.query(storiesURI, null, FeedProvider.getSelectionFromState(currentState), null, null);
		setTitle(getIntent().getStringExtra(EXTRA_USERNAME));
		setupPager(stories);

		markSocialAsReadList = new MarkSocialAsReadUpdate(userId);
		
		Story story = readingAdapter.getStory(passedPosition);
		markSocialAsReadList.add(story.feedId, story.id);
		
		new MarkStoryAsReadIntenallyTask(contentResolver).execute(story);
	}
	
	@Override
	public void onPageSelected(int position) {
		super.onPageSelected(position);
		Story story = readingAdapter.getStory(position);
		markSocialAsReadList.add(story.feedId, story.id);
	}

	@Override
	protected void onDestroy() {
		super.onDestroy();
		new MarkSocialStoryAsReadTask(this, syncFragment, markSocialAsReadList).execute();
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
	

	

}
