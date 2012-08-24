package com.newsblur.activity;

import android.database.Cursor;
import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MarkStoryAsReadIntenallyTask;
import com.newsblur.database.MixedFeedsReadingAdapter;
import com.newsblur.domain.Story;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.MarkMixedStoriesAsReadTask;

public class EverythingReading extends Reading {
	
	private Cursor stories;
	private ValueMultimap storiesToMarkAsRead;
	
	@Override
	protected void onCreate(Bundle savedInstanceBundle) {
		super.onCreate(savedInstanceBundle);

		stories = contentResolver.query(FeedProvider.ALL_STORIES_URI, null, FeedProvider.getSelectionFromState(currentState), null, null);
		setTitle(getResources().getString(R.string.everything));
		storiesToMarkAsRead = new ValueMultimap();
		readingAdapter = new MixedFeedsReadingAdapter(getSupportFragmentManager(), stories);

		setupPager();

		storiesToMarkAsRead.put(readingAdapter.getStory(passedPosition).feedId, readingAdapter.getStory(passedPosition).id);
		new MarkStoryAsReadIntenallyTask(contentResolver).execute(readingAdapter.getStory(passedPosition));
	}
	
	@Override
	public void onPageSelected(int position) {
		super.onPageSelected(position);
		storiesToMarkAsRead.put(readingAdapter.getStory(position).feedId, readingAdapter.getStory(position).id);
	}

	@Override
	protected void onDestroy() {
		new MarkMixedStoriesAsReadTask(this, syncFragment, storiesToMarkAsRead).execute();
		super.onDestroy();
	}
	
}
