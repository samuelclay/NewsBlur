package com.newsblur.util;

import android.content.Context;
import android.os.AsyncTask;
import android.util.Log;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.domain.Story;
import com.newsblur.network.APIManager;

public class FeedUtils {

	public static void saveStory(final Story story, final Context context, final APIManager apiManager) {
		if (story != null) {
            final String feedId = story.feedId;
            final String storyId = story.id;
            new AsyncTask<Void, Void, Boolean>() {
                @Override
                protected Boolean doInBackground(Void... arg) {
                    return apiManager.markStoryAsStarred(feedId, storyId);
                }
                @Override
                protected void onPostExecute(Boolean result) {
                    if (result) {
                        Toast.makeText(context, R.string.toast_story_saved, Toast.LENGTH_SHORT).show();
                    } else {
                        Toast.makeText(context, R.string.toast_story_save_error, Toast.LENGTH_LONG).show();
                    }
                }
            }.execute();
        } else {
            Log.w(FeedUtils.class.getName(), "Couldn't save story, no selection found.");
        }
	}
}
