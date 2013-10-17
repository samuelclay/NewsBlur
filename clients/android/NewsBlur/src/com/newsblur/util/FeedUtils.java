package com.newsblur.util;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import android.content.ContentProviderOperation;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.AsyncTask;
import android.text.TextUtils;
import android.util.Log;
import android.widget.Toast;

import com.google.gson.Gson;
import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.Story;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.service.SyncService;
import com.newsblur.util.AppConstants;

public class FeedUtils {

    private static Gson gson = new Gson();

	public static void saveStory(final Story story, final Context context, final APIManager apiManager) {
		if (story != null) {
            new AsyncTask<Void, Void, NewsBlurResponse>() {
                @Override
                protected NewsBlurResponse doInBackground(Void... arg) {
                    return apiManager.markStoryAsStarred(story.feedId, story.storyHash);
                }
                @Override
                protected void onPostExecute(NewsBlurResponse result) {
                    if (!result.isError()) {
                        Toast.makeText(context, R.string.toast_story_saved, Toast.LENGTH_SHORT).show();
                    } else {
                        Toast.makeText(context, result.getErrorMessage(context.getString(R.string.toast_story_save_error)), Toast.LENGTH_LONG).show();
                    }
                }
            }.execute();
        } else {
            Log.w(FeedUtils.class.getName(), "Couldn't save story, no selection found.");
        }
	}

    public static void deleteFeed( final long feedId, final String folderName, final Context context, final APIManager apiManager) {

        new AsyncTask<Void, Void, NewsBlurResponse>() {
            @Override
            protected NewsBlurResponse doInBackground(Void... arg) {
                return apiManager.deleteFeed(feedId, folderName);
            }
            @Override
            protected void onPostExecute(NewsBlurResponse result) {
                if (!result.isError()) {
                    Toast.makeText(context, R.string.toast_feed_deleted, Toast.LENGTH_SHORT).show();
                } else {
                    Toast.makeText(context, result.getErrorMessage(context.getString(R.string.toast_feed_delete_error)), Toast.LENGTH_LONG).show();
                }
            }
        }.execute();

        Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(Long.toString(feedId)).build();
        context.getContentResolver().delete(feedUri, null, null);

    }

    public static void markStoryUnread( final Story story, final Context context, final APIManager apiManager ) {

        new AsyncTask<Void, Void, NewsBlurResponse>() {
            @Override
            protected NewsBlurResponse doInBackground(Void... arg) {
                return apiManager.markStoryAsUnread(story.feedId, story.storyHash);
            }
            @Override
            protected void onPostExecute(NewsBlurResponse result) {
                if (!result.isError()) {
                    Toast.makeText(context, R.string.toast_story_unread, Toast.LENGTH_SHORT).show();
                } else {
                    Toast.makeText(context, result.getErrorMessage(context.getString(R.string.toast_story_unread_error)), Toast.LENGTH_LONG).show();
                }
            }
        }.execute();

    }

    /**
     * This utility method is a fast-returning way to mark as read a batch of stories in both
     * the local DB and on the server.
     */
    public static void markStoriesAsRead( Collection<Story> stories, final Context context ) {

        // the list of story hashes to mark read
        final ArrayList<String> storyHashes = new ArrayList<String>();
        // a list of local DB ops to perform
        ArrayList<ContentProviderOperation> updateOps = new ArrayList<ContentProviderOperation>();

        for (Story story : stories) {
            appendStoryReadOperations(story, updateOps);
            storyHashes.add(story.storyHash);
        }

        // first, update unread counts in the local DB
        try {
            context.getContentResolver().applyBatch(FeedProvider.AUTHORITY, updateOps);
        } catch (Exception e) {
            Log.w(FeedUtils.class.getName(), "Could not update unread counts in local storage.", e);
        }

        // next, update the server
        if (storyHashes.size() > 0) {
            new AsyncTask<Void, Void, NewsBlurResponse>() {
                @Override
                protected NewsBlurResponse doInBackground(Void... arg) {
                    APIManager apiManager = new APIManager(context);
                    return apiManager.markStoriesAsRead(storyHashes);
                }
                @Override
                protected void onPostExecute(NewsBlurResponse result) {
                    if (result.isError()) {
                        Log.e(FeedUtils.class.getName(), "Could not update unread counts via API: " + result.getErrorMessage());
                    }
                }
            }.execute();
        }

    }

	private static void appendStoryReadOperations(Story story, List<ContentProviderOperation> operations) {
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

    public static void updateClassifier(final String feedId, final String key, final Classifier classifier, final int classifierType, final int classifierAction, final Context context) {

        // first, update the server
        new AsyncTask<Void, Void, NewsBlurResponse>() {
            @Override
            protected NewsBlurResponse doInBackground(Void... arg) {
                APIManager apiManager = new APIManager(context);
                return apiManager.trainClassifier(feedId, key, classifierType, classifierAction);
            }
            @Override
            protected void onPostExecute(NewsBlurResponse result) {
                if (result.isError()) {
                    Toast.makeText(context, result.getErrorMessage(context.getString(R.string.error_saving_classifier)), Toast.LENGTH_LONG).show();
                }
            }
        }.execute();

        // next, update the local DB
        classifier.getMapForType(classifierType).put(key, classifierAction);
        Uri classifierUri = FeedProvider.CLASSIFIER_URI.buildUpon().appendPath(feedId).build();
        try {
            // TODO: for feeds with many classifiers, this could be much faster by targeting just the row that changed
			context.getContentResolver().delete(classifierUri, null, null);
			for (ContentValues classifierValues : classifier.getContentValues()) {
                context.getContentResolver().insert(classifierUri, classifierValues);
            }
        } catch (Exception e) {
            Log.w(FeedUtils.class.getName(), "Could not update classifier in local storage.", e);
        }

    }

    /** 
     * Gets the unread story count for a feed, filtered by view state.
     */
    public static int getFeedUnreadCount(Feed feed, int currentState) {
        if (feed == null ) return 0;
        int count = 0;
        count += feed.positiveCount;
        if ((currentState == AppConstants.STATE_ALL) || (currentState ==  AppConstants.STATE_SOME)) {
            count += feed.neutralCount;
        }
        if (currentState ==  AppConstants.STATE_ALL ) {
            count += feed.negativeCount;
        }
        return count;
    }

    public static int getFeedUnreadCount(SocialFeed feed, int currentState) {
        if (feed == null ) return 0;
        int count = 0;
        count += feed.positiveCount;
        if ((currentState == AppConstants.STATE_ALL) || (currentState ==  AppConstants.STATE_SOME)) {
            count += feed.neutralCount;
        }
        if (currentState ==  AppConstants.STATE_ALL ) {
            count += feed.negativeCount;
        }
        return count;
    }
    
    public static void shareStory(Story story, Context context) {
        Intent intent = new Intent(android.content.Intent.ACTION_SEND);
        intent.setType("text/plain");
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_WHEN_TASK_RESET);
        intent.putExtra(Intent.EXTRA_SUBJECT, story.title);
        final String shareString = context.getResources().getString(R.string.share);
        intent.putExtra(Intent.EXTRA_TEXT, String.format(shareString, new Object[] { story.title, story.permalink }));
        context.startActivity(Intent.createChooser(intent, "Share using"));
    }
}
