package com.newsblur.activity;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;

import com.newsblur.database.FeedProvider;
import com.newsblur.database.MarkStoryAsReadIntenallyTask;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.network.MarkStoryAsReadTask;

public class FeedReading extends Reading {

	private Cursor stories;
	protected Set<String> storiesToMarkAsRead;
	
	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);

		feedId = getIntent().getStringExtra(Reading.EXTRA_FEED);
		Uri storiesURI = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(feedId).build();
		
		stories = contentResolver.query(storiesURI, null, FeedProvider.getSelectionFromState(currentState), null, null);
		
		final Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
		Feed feed = Feed.fromCursor(contentResolver.query(feedUri, null, null, null, null));
		setTitle(feed.title);
		setupPager(stories);
		storiesToMarkAsRead = new HashSet<String>();
			
		createFloatingHeader(feed);
		Story story = readingAdapter.getStory(passedPosition);
		
		storiesToMarkAsRead.add(readingAdapter.getStory(passedPosition).id);
		new MarkStoryAsReadIntenallyTask(contentResolver).execute(story);
	}
	
	@Override
	public void onPageSelected(int position) {
		super.onPageSelected(position);
		storiesToMarkAsRead.add(readingAdapter.getStory(position).id);
		new MarkStoryAsReadIntenallyTask(contentResolver).execute(readingAdapter.getStory(position));
	}

	@Override
	protected void onDestroy() {
		ArrayList<String> storyIds = new ArrayList<String>();
		storyIds.addAll(storiesToMarkAsRead);
		new MarkStoryAsReadTask(this, syncFragment, storyIds, feedId).execute();
		super.onDestroy();
	}

}
