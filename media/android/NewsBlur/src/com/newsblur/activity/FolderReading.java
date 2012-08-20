package com.newsblur.activity;

import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;

import com.newsblur.database.FeedProvider;
import com.newsblur.database.MarkStoryAsReadIntenallyTask;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.domain.Story;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.MarkMixedStoriesAsReadTask;

public class FolderReading extends Reading {
	private Cursor stories;
	protected ValueMultimap storiesToMarkAsRead;
	private String[] feedIds;
	
	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);

		feedIds = getIntent().getStringArrayExtra(Reading.EXTRA_FEED_IDS);
		setTitle(getIntent().getStringExtra(Reading.EXTRA_FOLDERNAME));		
		
		Uri storiesURI = FeedProvider.MULTIFEED_STORIES_URI;
		storiesToMarkAsRead = new ValueMultimap();
		stories = contentResolver.query(storiesURI, null, FeedProvider.getSelectionFromState(currentState), feedIds, null);
		
		readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), stories);

		setupPager();
			
		Story story = readingAdapter.getStory(passedPosition);
		
		storiesToMarkAsRead.put(readingAdapter.getStory(passedPosition).feedId, readingAdapter.getStory(passedPosition).id);
		new MarkStoryAsReadIntenallyTask(contentResolver).execute(story);
	}
	
	@Override
	public void onPageSelected(int position) {
		super.onPageSelected(position);
		storiesToMarkAsRead.put(readingAdapter.getStory(position).feedId, readingAdapter.getStory(position).id);
		new MarkStoryAsReadIntenallyTask(contentResolver).execute(readingAdapter.getStory(position));
	}

	@Override
	protected void onDestroy() {
		new MarkMixedStoriesAsReadTask(this, syncFragment, storiesToMarkAsRead).execute();
		super.onDestroy();
	}

}
