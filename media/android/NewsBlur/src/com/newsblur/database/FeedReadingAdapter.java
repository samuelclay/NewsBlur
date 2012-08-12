package com.newsblur.database;

import android.database.Cursor;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;

import com.newsblur.activity.ReadingAdapter;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.fragment.LoadingFragment;
import com.newsblur.fragment.ReadingItemFragment;

public class FeedReadingAdapter extends ReadingAdapter {

	private final Feed feed;

	public FeedReadingAdapter(FragmentManager fm, Feed feed, Cursor stories) {
		super(fm, stories);
		this.feed = feed;
	}

	@Override
	public Fragment getItem(int position)  {
		if (stories == null || stories.getCount() == 0) {
			loadingFragment = new LoadingFragment();
			return loadingFragment;
		} else {
			stories.moveToPosition(position);
			return ReadingItemFragment.newInstance(Story.fromCursor(stories), feed.faviconColour, feed.faviconFade);
		}
	}
	
	

}
