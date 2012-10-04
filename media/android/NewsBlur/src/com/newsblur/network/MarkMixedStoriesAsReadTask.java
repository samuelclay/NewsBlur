package com.newsblur.network;

import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;

import com.newsblur.domain.ValueMultimap;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;

public class MarkMixedStoriesAsReadTask extends AsyncTask<Void, Void, Void> {

	private Context context;
	private SyncUpdateFragment receiver;
	private final ValueMultimap stories;
	
	public MarkMixedStoriesAsReadTask(final Context context, final SyncUpdateFragment fragment, final ValueMultimap stories) {
		this.context = context;
		this.receiver = fragment;
		this.stories = stories;
	}
	

	@Override
	protected Void doInBackground(Void... params) {
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, context, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, receiver.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_MARK_MULTIPLE_STORIES_READ);
		intent.putExtra(SyncService.EXTRA_TASK_STORIES, stories);
		context.startService(intent);
		
		return null;
	}


}
