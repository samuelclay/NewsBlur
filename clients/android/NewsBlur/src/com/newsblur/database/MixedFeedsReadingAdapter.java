package com.newsblur.database;

import android.content.ContentResolver;
import android.database.Cursor;
import android.net.Uri;
import android.app.Fragment;
import android.app.FragmentManager;

import com.newsblur.activity.ReadingAdapter;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.fragment.ReadingItemFragment;
import com.newsblur.util.DefaultFeedView;

public class MixedFeedsReadingAdapter extends ReadingAdapter {

	private final ContentResolver resolver; 

	public MixedFeedsReadingAdapter(final FragmentManager fragmentManager, final ContentResolver resolver, DefaultFeedView defaultFeedView, String sourceUserId) {
		super(fragmentManager, defaultFeedView, sourceUserId);
		this.resolver = resolver;
	}

	@Override
	protected synchronized ReadingItemFragment getReadingItemFragment(Story story) {
        String feedTitle = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_TITLE));
        String feedFaviconColor = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOR));
        String feedFaviconFade = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_FADE));
        String feedFaviconBorder = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_BORDER));
        String feedFaviconText = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_TEXT));
        String feedFaviconUrl = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_URL));
        
        Uri classifierUri = FeedProvider.CLASSIFIER_URI.buildUpon().appendPath(story.feedId).build();
        Cursor feedClassifierCursor = resolver.query(classifierUri, null, null, null, null);
        Classifier classifier = Classifier.fromCursor(feedClassifierCursor);
        
        return ReadingItemFragment.newInstance(story, feedTitle, feedFaviconColor, feedFaviconFade, feedFaviconBorder, feedFaviconText, feedFaviconUrl, classifier, true, defaultFeedView, sourceUserId);
	}
	
}
