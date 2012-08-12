package com.newsblur.database;

import android.database.Cursor;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;

import com.newsblur.activity.ReadingAdapter;
import com.newsblur.domain.Story;
import com.newsblur.fragment.LoadingFragment;
import com.newsblur.fragment.ReadingItemFragment;

public class SocialFeedReadingAdapter extends ReadingAdapter {

	private String TAG = "FeedReadingAdapter";
	private LoadingFragment loadingFragment; 

	public SocialFeedReadingAdapter(final FragmentManager fragmentManager, final Cursor cursor) {
		super(fragmentManager, cursor);
	}

	@Override
	public Fragment getItem(int position)  {
		if (stories == null || stories.getCount() == 0) {
			loadingFragment = new LoadingFragment();
			return loadingFragment;
		} else {
			stories.moveToPosition(position);
			String feedFaviconColor = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOUR));
			String feedFaviconFade = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_FADE));
			return ReadingItemFragment.newInstance(Story.fromCursor(stories), feedFaviconColor, feedFaviconFade);
		}
	}
	
}
