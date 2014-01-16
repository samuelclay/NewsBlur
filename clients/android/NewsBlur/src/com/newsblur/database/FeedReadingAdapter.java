package com.newsblur.database;

import android.database.Cursor;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;

import com.newsblur.activity.ReadingAdapter;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.fragment.LoadingFragment;
import com.newsblur.fragment.ReadingItemFragment;

public class FeedReadingAdapter extends ReadingAdapter {

	private final Feed feed;
	private Classifier classifier;

	public FeedReadingAdapter(FragmentManager fm, Feed feed, Classifier classifier) {
		super(fm);
		this.feed = feed;
		this.classifier = classifier;
	}

	@Override
	protected synchronized Fragment getReadingItemFragment(int position) {
        stories.moveToPosition(position);
        return ReadingItemFragment.newInstance(Story.fromCursor(stories), feed.title, feed.faviconColor, feed.faviconFade, feed.faviconBorder, feed.faviconText, feed.faviconUrl, classifier, false);
	}

}
