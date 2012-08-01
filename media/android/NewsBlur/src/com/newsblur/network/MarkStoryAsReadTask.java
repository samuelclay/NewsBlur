package com.newsblur.network;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.AsyncTask;
import android.util.Log;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;

public class MarkStoryAsReadTask extends AsyncTask<Story, Void, Void> {

	private ContentResolver contentResolver;
	private Context context;
	private SyncUpdateFragment receiver;
	private Feed feed;
	
	public MarkStoryAsReadTask(final Context context, final ContentResolver resolver, final SyncUpdateFragment fragment) {
		this.contentResolver = resolver;
		this.context = context;
		this.receiver = fragment;
	}
	
	protected Void doInBackground(Story... params) {
		for (Story story : params) {
			if (story.read.equals("0")) {
				
				String[] selectionArgs; 
				if (story.getIntelligenceTotal() > 0) {
					selectionArgs = new String[] { DatabaseConstants.FEED_POSITIVE_COUNT, story.feedId } ; 
				} else if (story.getIntelligenceTotal() == 0) {
					selectionArgs = new String[] { DatabaseConstants.FEED_NEUTRAL_COUNT, story.feedId } ;
				} else {
					selectionArgs = new String[] { DatabaseConstants.FEED_NEGATIVE_COUNT, story.feedId } ;
				}
				Log.d("TAG", "Returned: " + contentResolver.update(FeedProvider.MODIFY_COUNT_URI, null, null, selectionArgs));
				
				Uri storyUri = FeedProvider.STORY_URI.buildUpon().appendPath(story.id).build();
				ContentValues values = new ContentValues();
				values.put(DatabaseConstants.STORY_READ, true);
				contentResolver.update(storyUri, values, null, null);
				
				final Intent intent = new Intent(Intent.ACTION_SYNC, null, context, SyncService.class);
				intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, receiver.receiver);
				intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_MARK_STORY_READ);
				intent.putExtra(SyncService.EXTRA_TASK_FEED_ID, story.feedId);
				intent.putExtra(SyncService.EXTRA_TASK_STORY_ID, story.id);
				context.startService(intent);

				story.read = "1";
			}
		}
		return null;
	}

}
