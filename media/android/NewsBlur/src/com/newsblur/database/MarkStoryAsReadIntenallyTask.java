package com.newsblur.database;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.net.Uri;
import android.os.AsyncTask;
import android.text.TextUtils;

import com.newsblur.domain.Story;

public class MarkStoryAsReadIntenallyTask extends AsyncTask<Story, Void, Void>{

	private ContentResolver contentResolver;

	public MarkStoryAsReadIntenallyTask(final ContentResolver resolver) {
		this.contentResolver = resolver;
	}
	
	@Override
	protected Void doInBackground(Story... params) {
		for (Story story : params) {
			String[] selectionArgs; 
			if (story.getIntelligenceTotal() > 0) {
				selectionArgs = new String[] { DatabaseConstants.FEED_POSITIVE_COUNT, story.feedId } ; 
			} else if (story.getIntelligenceTotal() == 0) {
				selectionArgs = new String[] { DatabaseConstants.FEED_NEUTRAL_COUNT, story.feedId } ;
			} else {
				selectionArgs = new String[] { DatabaseConstants.FEED_NEGATIVE_COUNT, story.feedId } ;
			}
			contentResolver.update(FeedProvider.MODIFY_COUNT_URI, null, null, selectionArgs);

			if (!TextUtils.isEmpty(story.socialUserId)) {
				String[] socialSelectionArgs; 
				if (story.getIntelligenceTotal() > 0) {
					socialSelectionArgs = new String[] { DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT, story.socialUserId } ; 
				} else if (story.getIntelligenceTotal() == 0) {
					socialSelectionArgs = new String[] { DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT, story.socialUserId } ;
				} else {
					socialSelectionArgs = new String[] { DatabaseConstants.SOCIAL_FEED_NEGATIVE_COUNT, story.socialUserId } ;
				}
				contentResolver.update(FeedProvider.MODIFY_SOCIALCOUNT_URI, null, null, socialSelectionArgs);
			}

			Uri storyUri = FeedProvider.STORY_URI.buildUpon().appendPath(story.id).build();
			ContentValues values = new ContentValues();
			values.put(DatabaseConstants.STORY_READ, true);
			contentResolver.update(storyUri, values, null, null);
		}
		
		return null;
	}
}
