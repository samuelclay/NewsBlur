package com.newsblur.network;

import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;

import com.google.gson.Gson;
import com.newsblur.activity.SocialFeedReading.MarkSocialAsReadUpdate;
import com.newsblur.domain.Story;
import com.newsblur.fragment.SyncUpdateFragment;
import com.newsblur.service.SyncService;

public class MarkSocialStoryAsReadTask extends AsyncTask<Story, Void, Void> {

	private Context context;
	private SyncUpdateFragment receiver;
	private Gson gson;
	private final MarkSocialAsReadUpdate readUpdate;
	
	public MarkSocialStoryAsReadTask(final Context context, final SyncUpdateFragment fragment, MarkSocialAsReadUpdate update) {
		this.context = context;
		this.receiver = fragment;
		this.readUpdate = update;
		
		gson = new Gson();
	}
	
	protected Void doInBackground(Story... params) {
		
		final Intent intent = new Intent(Intent.ACTION_SYNC, null, context, SyncService.class);
		intent.putExtra(SyncService.EXTRA_STATUS_RECEIVER, receiver.receiver);
		intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_MARK_SOCIALSTORY_READ);
		intent.putExtra(SyncService.EXTRA_TASK_MARK_SOCIAL_JSON, gson.toJson(readUpdate.getJsonObject()));
		context.startService(intent);
		
		return null;
	}

}
