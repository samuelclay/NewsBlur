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
import com.newsblur.domain.Story;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.service.SyncService;

public class FeedUtils {

    private static Gson gson = new Gson();

	public static void saveStory(final Story story, final Context context, final APIManager apiManager) {
		if (story != null) {
            final String feedId = story.feedId;
            final String storyId = story.id;
            new AsyncTask<Void, Void, NewsBlurResponse>() {
                @Override
                protected NewsBlurResponse doInBackground(Void... arg) {
                    return apiManager.markStoryAsStarred(feedId, storyId);
                }
                @Override
                protected void onPostExecute(NewsBlurResponse result) {
                    if (!result.isError()) {
                        Toast.makeText(context, R.string.toast_story_saved, Toast.LENGTH_SHORT).show();
                    } else {
                        Toast.makeText(context, result.getErrorMessage(), Toast.LENGTH_LONG).show();
                    }
                }
            }.execute();
        } else {
            Log.w(FeedUtils.class.getName(), "Couldn't save story, no selection found.");
        }
	}

    public static void markStoryUnread( final Story story, final Context context, final APIManager apiManager) {

        new AsyncTask<Void, Void, NewsBlurResponse>() {
            @Override
            protected NewsBlurResponse doInBackground(Void... arg) {
                return apiManager.markStoryAsUnread(story.feedId, story.id);
            }
            @Override
            protected void onPostExecute(NewsBlurResponse result) {
                if (!result.isError()) {
                    Toast.makeText(context, R.string.toast_story_unread, Toast.LENGTH_SHORT).show();
                } else {
                    Toast.makeText(context, result.getErrorMessage(), Toast.LENGTH_LONG).show();
                }
            }
        }.execute();

    }

    /**
     * This utility method is a fast-returning way to mark as read a batch of stories in both
     * the local DB and on the server.
     *
     * TODO: the next version of the NB API will let us mark-as-read by a UUID, so we can
     *       hopefully remove the ugly detection of social stories and their whole different
     *       API call.
     */
    public static void markStoriesAsRead( Collection<Story> stories, Context context ) {

        // the map of non-social feedIds->storyIds to mark (auto-serializing)
        ValueMultimap storiesJson = new ValueMultimap();
        // the map of social userIds->feedIds->storyIds to mark
        Map<String, Map<String, Set<String>>> socialStories = new HashMap<String, Map<String, Set<String>>>();
        // a list of local DB ops to perform
        ArrayList<ContentProviderOperation> updateOps = new ArrayList<ContentProviderOperation>();

        for (Story story : stories) {
            appendStoryReadOperations(story, updateOps);
            if (story.socialUserId != null) {
                // TODO: some stories returned by /social/river_stories seem to have neither a
                //  socialUserId nor a sourceUserId, so they accidentally get submitted non-
                //  socially.  If the API fixes this before we ditch social-specific logic,
                //  we can fix that bug right here.
                putMapHeirarchy(socialStories, story.socialUserId, story.feedId, story.id);
            } else {
                storiesJson.put(story.feedId, story.id);
            }
        }

        // first, update unread counts in the local DB
        try {
            context.getContentResolver().applyBatch(FeedProvider.AUTHORITY, updateOps);
        } catch (Exception e) {
            Log.w(FeedUtils.class.getName(), "Could not update unread counts in local storage.", e);
        }

        // next, update the server for normal stories
        if (storiesJson.size() > 0) {
            Intent intent = new Intent(Intent.ACTION_SYNC, null, context, SyncService.class);
            intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_MARK_MULTIPLE_STORIES_READ);
            intent.putExtra(SyncService.EXTRA_TASK_STORIES, storiesJson);
            context.startService(intent);
        }

        // finally, update the server for social stories
        if (socialStories.size() > 0) {
            Intent intent = new Intent(Intent.ACTION_SYNC, null, context, SyncService.class);
            intent.putExtra(SyncService.SYNCSERVICE_TASK, SyncService.EXTRA_TASK_MARK_SOCIALSTORY_READ);
            intent.putExtra(SyncService.EXTRA_TASK_MARK_SOCIAL_JSON, gson.toJson(socialStories));
            context.startService(intent);
        }

    }

    /**
     * A utility method to help populate the 3-level map structure that the NB API uses in JSON calls.
     */
    private static void putMapHeirarchy(Map<String, Map<String, Set<String>>> map, String s1, String s2, String s3) {
        if (! map.containsKey(s1)) {
            map.put(s1, new HashMap<String, Set<String>>());
        }
        Map<String, Set<String>> innerMap = map.get(s1);
        if (! innerMap.containsKey(s2)) {
            innerMap.put(s2, new HashSet<String>());
        }
        innerMap.get(s2).add(s3);
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
}
