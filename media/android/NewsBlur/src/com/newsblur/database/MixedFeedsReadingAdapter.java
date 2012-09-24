package com.newsblur.database;

import android.content.ContentResolver;
import android.database.Cursor;
import android.net.Uri;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;

import com.newsblur.activity.ReadingAdapter;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.fragment.LoadingFragment;
import com.newsblur.fragment.ReadingItemFragment;

public class MixedFeedsReadingAdapter extends ReadingAdapter {

	private String TAG = "FeedReadingAdapter";
	private LoadingFragment loadingFragment;
	private final ContentResolver resolver; 

	public MixedFeedsReadingAdapter(final FragmentManager fragmentManager, final ContentResolver resolver, final Cursor cursor) {
		super(fragmentManager, cursor);
		this.resolver = resolver;
	}

	@Override
	public Fragment getItem(int position)  {
		if (stories == null || stories.getCount() == 0) {
			loadingFragment = new LoadingFragment();
			return loadingFragment;
		} else {
			stories.moveToPosition(position);
			Story story = Story.fromCursor(stories);
			String feedTitle = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_TITLE));
			String feedFaviconColor = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_BORDER));
			String feedFaviconFade = stories.getString(stories.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOUR));
			
			Uri classifierUri = FeedProvider.CLASSIFIER_URI.buildUpon().appendPath(story.feedId).build();
			Cursor feedClassifierCursor = resolver.query(classifierUri, null, null, null, null);
			Classifier classifier = Classifier.fromCursor(feedClassifierCursor);
			
			return ReadingItemFragment.newInstance(story, feedTitle, feedFaviconColor, feedFaviconFade, classifier, true);
		}
	}
	
}
