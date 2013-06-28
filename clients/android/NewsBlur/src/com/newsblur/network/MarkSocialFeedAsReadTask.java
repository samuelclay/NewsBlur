package com.newsblur.network;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.os.AsyncTask;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;

public abstract class MarkSocialFeedAsReadTask extends AsyncTask<String, Void, Boolean> {
	
	private final APIManager apiManager;
	private final ContentResolver resolver;
	private String feedId;

	public MarkSocialFeedAsReadTask(final APIManager apiManager, final ContentResolver resolver) {
		this.apiManager = apiManager;
		this.resolver = resolver;
	}
	
	@Override
	protected Boolean doInBackground(String... id) {
		this.feedId = id[0];
		if (apiManager.markFeedAsRead(new String[] { "social:" + id[0] })) {
			ContentValues values = new ContentValues();
			values.put(DatabaseConstants.SOCIAL_FEED_NEGATIVE_COUNT, 0);
			values.put(DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT, 0);
			values.put(DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT, 0);
			resolver.update(FeedProvider.SOCIAL_FEEDS_URI.buildUpon().appendPath(feedId).build(), values, null, null);
			return true;
		} else {
			return false;
		}
			
	}

	@Override
	protected abstract void onPostExecute(Boolean result);
	
}
