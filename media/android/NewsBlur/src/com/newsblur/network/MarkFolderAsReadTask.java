package com.newsblur.network;

import java.util.ArrayList;
import java.util.List;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.database.Cursor;
import android.net.Uri;
import android.os.AsyncTask;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;

public abstract class MarkFolderAsReadTask extends AsyncTask<String, Void, Boolean> {
	List<String> feedIds = new ArrayList<String>();
	private APIManager apiManager;
	private ContentResolver resolver;
	
	public MarkFolderAsReadTask(final APIManager apiManager, final ContentResolver resolver) {
		this.apiManager = apiManager;
		this.resolver = resolver;
	}
	
	@Override
	protected Boolean doInBackground(String... folderId) {
		Uri feedsUri = FeedProvider.FEED_FOLDER_MAP_URI.buildUpon().appendPath(folderId[0]).build();
		Cursor feedCursor = resolver.query(feedsUri, new String[] { DatabaseConstants.FEED_ID }, null, null, null);
		while (feedCursor.moveToNext()) {
			feedIds.add(feedCursor.getString(feedCursor.getColumnIndex(DatabaseConstants.FEED_ID)));
		}
		
		boolean result = apiManager.markFeedAsRead(feedIds.toArray(new String[feedIds.size()]));
		if (result) {
			ContentValues values = new ContentValues();
			values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, 0);
			values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, 0);
			values.put(DatabaseConstants.FEED_POSITIVE_COUNT, 0);
			for (String feedId : feedIds) {
				resolver.update(FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build(), values, null, null);
			}
		}
		
		return result;
	}
	
	@Override
	protected abstract void onPostExecute(Boolean result);
}