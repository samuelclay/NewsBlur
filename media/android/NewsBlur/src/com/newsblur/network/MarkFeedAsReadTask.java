package com.newsblur.network;

import android.content.Context;
import android.os.AsyncTask;

public abstract class MarkFeedAsReadTask extends AsyncTask<String, Void, Boolean> {
	
	private final APIManager apiManager;

	public MarkFeedAsReadTask(final Context context, final APIManager apiManager) {
		this.apiManager = apiManager;
	}
	
	@Override
	protected Boolean doInBackground(String... id) {
		return apiManager.markFeedAsRead(id);
	}

	@Override
	protected abstract void onPostExecute(Boolean result);
	
}
