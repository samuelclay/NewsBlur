package com.newsblur.network;

import java.util.ArrayList;

import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;

import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;

public class MarkStoryAsReadTask extends AsyncTask<Void, Void, Void> {

	private Context context;
	private SyncUpdateFragment receiver;
	private final String feedId;
	private final ArrayList<String> storyIds;
	
	public MarkStoryAsReadTask(final Context context, final SyncUpdateFragment fragment, final ArrayList<String> storyIds, final String feedId) {
		this.context = context;
		this.receiver = fragment;
		this.storyIds = storyIds;
		this.feedId = feedId;
	}
	
	protected Void doInBackground(Void... stories) {
		
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, context, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, receiver.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_MARK_STORY_READ);
		intent.putExtra(SyncService.EXTRA_TASK_FEED_ID, feedId);
		intent.putStringArrayListExtra(SyncService.EXTRA_TASK_STORY_ID, storyIds);
		context.startService(intent);
		
		return null;
	}

}
