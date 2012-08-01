package com.newsblur.network;

import java.util.ArrayList;
import java.util.List;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.os.AsyncTask;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.database.MixedExpandableListAdapter;

public class MarkFolderAsReadTask extends AsyncTask<String, Void, Boolean> {
	List<String> feedIds = new ArrayList<String>();
	private Context context;
	private APIManager apiManager;
	private ContentResolver resolver;
	private MixedExpandableListAdapter adapter;
	
	public MarkFolderAsReadTask(final Context context, final APIManager apiManager, final ContentResolver resolver, final MixedExpandableListAdapter adapter) {
		this.context = context;
		this.apiManager = apiManager;
		this.resolver = resolver;
		this.adapter = adapter;
	}
	
	@Override
	protected Boolean doInBackground(String... folderId) {
		Uri feedsUri = FeedProvider.FEED_FOLDER_MAP_URI.buildUpon().appendPath(folderId[0]).build();
		Cursor feedCursor = resolver.query(feedsUri, new String[] { DatabaseConstants.FEED_ID }, null, null, null);
		while (feedCursor.moveToNext()) {
			feedIds.add(feedCursor.getString(feedCursor.getColumnIndex(DatabaseConstants.FEED_ID)));
		}
		return apiManager.markFeedAsRead(feedIds.toArray(new String[feedIds.size()]));
	}
	
	@Override
	protected void onPostExecute(Boolean result) {
		if (result) {
			ContentValues values = new ContentValues();
			values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, 0);
			values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, 0);
			values.put(DatabaseConstants.FEED_POSITIVE_COUNT, 0);
			for (String feedId : feedIds) {
				resolver.update(FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build(), values, null, null);
			}
			adapter.requery();
			Toast.makeText(context, R.string.toast_marked_folder_as_read, Toast.LENGTH_SHORT).show();
		} else {
			Toast.makeText(context, R.string.toast_error_marking_feed_as_read, Toast.LENGTH_SHORT).show();
		}
	}
}