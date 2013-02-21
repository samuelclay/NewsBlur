package com.newsblur.network;

import java.util.ArrayList;
import java.util.List;

import android.content.ContentValues;
import android.os.AsyncTask;

import com.newsblur.domain.ValueMultimap;

public abstract class MarkAllStoriesAsReadTask extends AsyncTask<ValueMultimap, Void, Boolean> {
	List<String> feedIds = new ArrayList<String>();
	private APIManager apiManager;
	
	public MarkAllStoriesAsReadTask(final APIManager apiManager) {
		this.apiManager = apiManager;
	}
	
	@Override
	protected Boolean doInBackground(ValueMultimap... params) {
		ValueMultimap stories = params[0];
		if (stories.size() == 0) {
			return true;
		}
		else {
			ContentValues values = new ContentValues();
			values.put(APIConstants.PARAMETER_FEEDS_STORIES, stories.getJsonString());
    	    return apiManager.markMultipleStoriesAsRead(values);
		}
	}

	@Override
	protected abstract void onPostExecute(Boolean result);
}