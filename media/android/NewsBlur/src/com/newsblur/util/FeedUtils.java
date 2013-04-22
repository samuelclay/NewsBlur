package com.newsblur.util;

import java.util.ArrayList;

import android.content.ContentProviderOperation;
import android.content.ContentValues;
import android.content.Context;
import android.net.Uri;
import android.os.AsyncTask;
import android.text.TextUtils;
import android.util.Log;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
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

	public static void appendStoryReadOperations(Story story, ArrayList<ContentProviderOperation> operations) {
		String[] selectionArgs; 
		ContentValues emptyValues = new ContentValues();
		emptyValues.put(DatabaseConstants.FEED_ID, story.feedId);

		if (story.getIntelligenceTotal() > 0) {
			selectionArgs = new String[] { DatabaseConstants.FEED_POSITIVE_COUNT, story.feedId } ; 
		} else if (story.getIntelligenceTotal() == 0) {
			selectionArgs = new String[] { DatabaseConstants.FEED_NEUTRAL_COUNT, story.feedId } ;
		} else {
			selectionArgs = new String[] { DatabaseConstants.FEED_NEGATIVE_COUNT, story.feedId } ;
		}
		
		operations.add(ContentProviderOperation.newUpdate(FeedProvider.FEED_COUNT_URI).withValues(emptyValues).withSelection("", selectionArgs).build());

		if (!TextUtils.isEmpty(story.socialUserId)) {
			String[] socialSelectionArgs; 
			if (story.getIntelligenceTotal() > 0) {
				socialSelectionArgs = new String[] { DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT, story.socialUserId } ; 
			} else if (story.getIntelligenceTotal() == 0) {
				socialSelectionArgs = new String[] { DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT, story.socialUserId } ;
			} else {
				socialSelectionArgs = new String[] { DatabaseConstants.SOCIAL_FEED_NEGATIVE_COUNT, story.socialUserId } ;
			}
			operations.add(ContentProviderOperation.newUpdate(FeedProvider.SOCIALCOUNT_URI).withValues(emptyValues).withSelection("", socialSelectionArgs).build());
		}

		Uri storyUri = FeedProvider.STORY_URI.buildUpon().appendPath(story.id).build();
		ContentValues values = new ContentValues();
		values.put(DatabaseConstants.STORY_READ, true);

		operations.add(ContentProviderOperation.newUpdate(storyUri).withValues(values).build());
	}
}
