package com.newsblur.database;

import android.app.FragmentManager;

import com.newsblur.activity.ReadingAdapter;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.fragment.ReadingItemFragment;
import com.newsblur.util.FeedUtils;

public class MixedFeedsReadingAdapter extends ReadingAdapter {

	public MixedFeedsReadingAdapter(FragmentManager fragmentManager, String sourceUserId) {
		super(fragmentManager, sourceUserId);
	}

	@Override
	protected synchronized ReadingItemFragment getReadingItemFragment(Story story) {
        String feedTitle = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_TITLE));
        String feedFaviconColor = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOR));
        String feedFaviconFade = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_FADE));
        String feedFaviconBorder = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_BORDER));
        String feedFaviconText = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_TEXT));
        String feedFaviconUrl = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_URL));
        
        // TODO: does the pager generate new fragments in the UI thread? If so, classifiers should
        // be loaded async by the fragment itself
        Classifier classifier = FeedUtils.dbHelper.getClassifierForFeed(story.feedId);
        
        return ReadingItemFragment.newInstance(story, feedTitle, feedFaviconColor, feedFaviconFade, feedFaviconBorder, feedFaviconText, feedFaviconUrl, classifier, true, sourceUserId);
	}

}
