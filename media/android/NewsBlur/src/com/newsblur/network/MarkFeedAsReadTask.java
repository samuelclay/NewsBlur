package com.newsblur.network;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.os.AsyncTask;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedExpandableListAdapter;

public class MarkFeedAsReadTask extends AsyncTask<String, Void, Boolean> {
	
	private final APIManager apiManager;
	private final Context context;
	private final ContentResolver resolver;
	private final MixedExpandableListAdapter adapter;
	private String feedId;

	public MarkFeedAsReadTask(final Context context, final APIManager apiManager, final ContentResolver resolver, final MixedExpandableListAdapter adapter) {
		this.context = context;
		this.apiManager = apiManager;
		this.resolver = resolver;
		this.adapter = adapter;
	}
	
	@Override
	protected Boolean doInBackground(String... id) {
		this.feedId = id[0];
		return apiManager.markFeedAsRead(id);
	}

	@Override
	protected void onPostExecute(Boolean result) {
		if (result.booleanValue()) {
			ContentValues values = new ContentValues();
			values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, 0);
			values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, 0);
			values.put(DatabaseConstants.FEED_POSITIVE_COUNT, 0);
			resolver.update(FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build(), values, null, null);
			adapter.requery();
			Toast.makeText(context, R.string.toast_marked_feed_as_read, Toast.LENGTH_SHORT).show();
			
		} else {
			Toast.makeText(context, R.string.toast_error_marking_feed_as_read, Toast.LENGTH_LONG).show();
		}
	}
	
}
