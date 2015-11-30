package com.newsblur.database;

import android.app.FragmentManager;

import com.newsblur.activity.ReadingAdapter;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.fragment.ReadingItemFragment;
import com.newsblur.util.DefaultFeedView;

public class FeedReadingAdapter extends ReadingAdapter {

	private final Feed feed;
	private Classifier classifier;

	public FeedReadingAdapter(FragmentManager fm, Feed feed, Classifier classifier, DefaultFeedView defaultFeedView) {
        // sourceUserId not required for feed reading
		super(fm, defaultFeedView, null);
		this.feed = feed;
		this.classifier = classifier;
    }

	@Override
	protected synchronized ReadingItemFragment getReadingItemFragment(Story story) {
        return ReadingItemFragment.newInstance(story, feed.title, feed.faviconColor, feed.faviconFade, feed.faviconBorder, feed.faviconText, feed.faviconUrl, classifier, false, defaultFeedView, sourceUserId);
	}

}
