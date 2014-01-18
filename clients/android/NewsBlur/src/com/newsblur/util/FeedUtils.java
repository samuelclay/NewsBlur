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
import android.database.Cursor;
import android.net.Uri;
import android.os.AsyncTask;
import android.text.Html;
import android.text.TextUtils;
import android.util.Log;
import android.widget.Toast;

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
import com.newsblur.network.domain.SocialFeedResponse;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.service.SyncService;
import com.newsblur.util.AppConstants;

public class FeedUtils {

    public static void updateFeed(final Context context, final ActionCompletionListener receiver, final String feedId, final int pageNumber, final StoryOrder order, final ReadFilter filter) {
        new AsyncTask<Void, Void, StoriesResponse>() {
            @Override
            protected StoriesResponse doInBackground(Void... arg) {
                APIManager apiManager = new APIManager(context);
                return apiManager.getStoriesForFeed(feedId, pageNumber, order, filter);
            }
            @Override
            protected void onPostExecute(StoriesResponse result) {
                handleStoryResponse(context, result, result.stories, receiver);
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

    public static void updateFeeds(final Context context, final ActionCompletionListener receiver, final String[] feedIds, final int pageNumber, final StoryOrder order, final ReadFilter filter) {
        new AsyncTask<Void, Void, StoriesResponse>() {
            @Override
            protected StoriesResponse doInBackground(Void... arg) {
                APIManager apiManager = new APIManager(context);
                return apiManager.getStoriesForFeeds(feedIds, pageNumber, order, filter);
            }
            @Override
            protected void onPostExecute(StoriesResponse result) {
                handleStoryResponse(context, result, result.stories, receiver);
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

    public static void updateSocialFeed(final Context context, final ActionCompletionListener receiver, final String feedId, final String socialUsername, final int pageNumber, final StoryOrder order, final ReadFilter filter) {
        new AsyncTask<Void, Void, SocialFeedResponse>() {
            @Override
            protected SocialFeedResponse doInBackground(Void... arg) {
                APIManager apiManager = new APIManager(context);
                return apiManager.getStoriesForSocialFeed(feedId, socialUsername, pageNumber, order, filter);
            }
            @Override
            protected void onPostExecute(SocialFeedResponse result) {
                handleStoryResponse(context, result, result.stories, receiver);
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

    public static void updateSocialFeeds(final Context context, final ActionCompletionListener receiver, final String[] feedIds, final int pageNumber, final StoryOrder order, final ReadFilter filter) {
        new AsyncTask<Void, Void, SocialFeedResponse>() {
            @Override
            protected SocialFeedResponse doInBackground(Void... arg) {
                APIManager apiManager = new APIManager(context);
                return apiManager.getSharedStoriesForFeeds(feedIds, pageNumber, order, filter);
            }
            @Override
            protected void onPostExecute(SocialFeedResponse result) {
                handleStoryResponse(context, result, result.stories, receiver);
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

    public static void updateSavedStories(final Context context, final ActionCompletionListener receiver, final int pageNumber) {
        new AsyncTask<Void, Void, StoriesResponse>() {
            @Override
            protected StoriesResponse doInBackground(Void... arg) {
                APIManager apiManager = new APIManager(context);
                return apiManager.getStarredStories(pageNumber);
            }
            @Override
            protected void onPostExecute(StoriesResponse result) {
                handleStoryResponse(context, result, result.stories, receiver);
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

    public static void clearStories(final Context context) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                context.getContentResolver().delete(FeedProvider.ALL_STORIES_URI, null, null);
                return null;
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
    }

    private static void handleStoryResponse(Context context, NewsBlurResponse response, Story[] stories, ActionCompletionListener receiver) {
        // the API may return both a valid stories block *and* an error, so check for stories first
        if (stories != null) {
            if (receiver != null) {
                receiver.actionCompleteCallback(stories.length == 0); // only keep loading if there are more stories left
            }
            return;
        }

        if (response.isError()) {
            Log.e(FeedUtils.class.getName(), "Error response received loading stories.");
            Toast.makeText(context, response.getErrorMessage(context.getString(R.string.toast_error_loading_stories)), Toast.LENGTH_LONG).show();
        } else {
            Log.e(FeedUtils.class.getName(), "Null stories member received while loading stories with no error found.");
            Toast.makeText(context, R.string.toast_error_loading_stories, Toast.LENGTH_LONG).show();
        }

        // NB: we do not keep loading on error, since the calling class would need to know to adjust pagination
        receiver.actionCompleteCallback(true);
    }

	private static void setStorySaved(final Story story, final boolean saved, final Context context, final APIManager apiManager, final ActionCompletionListener receiver) {
        new AsyncTask<Void, Void, NewsBlurResponse>() {
            @Override
            protected NewsBlurResponse doInBackground(Void... arg) {
                if (saved) {
                    return apiManager.markStoryAsStarred(story.feedId, story.storyHash);
                } else {
                    return apiManager.markStoryAsUnstarred(story.feedId, story.storyHash);
                }
            }
            @Override
            protected void onPostExecute(NewsBlurResponse result) {
                if (!result.isError()) {
                    Toast.makeText(context, (saved ? R.string.toast_story_saved : R.string.toast_story_unsaved), Toast.LENGTH_SHORT).show();
                    story.starred = saved;
                    Uri storyUri = FeedProvider.STORY_URI.buildUpon().appendPath(story.id).build();
                    ContentValues values = new ContentValues();
                    values.put(DatabaseConstants.STORY_STARRED, saved);
                    context.getContentResolver().update(storyUri, values, null, null);
                } else {
                    Toast.makeText(context, result.getErrorMessage(context.getString(saved ? R.string.toast_story_save_error : R.string.toast_story_unsave_error)), Toast.LENGTH_LONG).show();
                }

                if (receiver != null) {
                    receiver.actionCompleteCallback(false);
                }
            }
        }.execute();
	}

	public static void saveStory(final Story story, final Context context, final APIManager apiManager, ActionCompletionListener receiver) {
        setStorySaved(story, true, context, apiManager, receiver);
    }

	public static void unsaveStory(final Story story, final Context context, final APIManager apiManager, ActionCompletionListener receiver) {
        setStorySaved(story, false, context, apiManager, receiver);
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

    public static void markStoryUnread(final Story story, final Context context) {
        // TODO: update DB, too
        new AsyncTask<Void, Void, NewsBlurResponse>() {
            @Override
            protected NewsBlurResponse doInBackground(Void... arg) {
                APIManager apiManager = new APIManager(context);
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
     * Mark a single story as read on both the local DB and on the server.
     */
    public static void markStoryAsRead(final Story story, final Context context) {
        if (story.read) { return; }

        // it is imperative that we are idempotent.  query the DB for a fresh copy of the story
        // to ensure it isn't already marked as read.  if so, do not update feed counts
        Uri storyUri = FeedProvider.STORY_URI.buildUpon().appendPath(story.id).build();
        Cursor cursor = context.getContentResolver().query(storyUri, null, null, null, null);
        if (cursor.getCount() < 1) {
            Log.w(FeedUtils.class.getName(), "can't mark story as read, not found in DB: " + story.id);
            return;
        }
        Story freshStory = Story.fromCursor(cursor);
        cursor.close();
        if (freshStory.read) { return; }

        // update the local object to show as read even before requeried
        story.read = true;

        // first, update unread counts in the local DB
        ArrayList<ContentProviderOperation> updateOps = new ArrayList<ContentProviderOperation>();
        appendStoryReadOperations(story, updateOps);
        try {
            context.getContentResolver().applyBatch(FeedProvider.AUTHORITY, updateOps);
        } catch (Exception e) {
            Log.w(FeedUtils.class.getName(), "Could not update unread counts in local storage.", e);
        }

        // next, update the server
        new AsyncTask<Void, Void, NewsBlurResponse>() {
            @Override
            protected NewsBlurResponse doInBackground(Void... arg) {
                APIManager apiManager = new APIManager(context);
                return apiManager.markStoryAsRead(story.storyHash);
            }
            @Override
            protected void onPostExecute(NewsBlurResponse result) {
                if (result.isError()) {
                    Log.e(FeedUtils.class.getName(), "Could not update unread counts via API: " + result.getErrorMessage());
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

        // update the local object to show as read even before requeried
        for (Story story : stories) {
            story.read = true;
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

        HashSet<String> socialIds = new HashSet<String>();
        if (!TextUtils.isEmpty(story.socialUserId)) {
            socialIds.add(story.socialUserId);
        }
        if (story.friendUserIds != null) {
            for (String id : story.friendUserIds) {
                socialIds.add(id);
            }
        }
        for (String id : socialIds) {
            String[] socialSelectionArgs; 
            if (story.getIntelligenceTotal() > 0) {
                socialSelectionArgs = new String[] { DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT, id } ; 
            } else if (story.getIntelligenceTotal() == 0) {
                socialSelectionArgs = new String[] { DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT, id } ;
            } else {
                socialSelectionArgs = new String[] { DatabaseConstants.SOCIAL_FEED_NEGATIVE_COUNT, id } ;
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

    public static int getCursorUnreadCount(Cursor cursor, int currentState) {
        int count = 0;
        for (int i = 0; i < cursor.getCount(); i++) {
            cursor.moveToPosition(i);
            count += cursor.getInt(cursor.getColumnIndexOrThrow(DatabaseConstants.SUM_POS));
            if ((currentState == AppConstants.STATE_ALL) || (currentState ==  AppConstants.STATE_SOME)) {
                count += cursor.getInt(cursor.getColumnIndexOrThrow(DatabaseConstants.SUM_NEUT));
            }
            if (currentState ==  AppConstants.STATE_ALL ) {
                count += cursor.getInt(cursor.getColumnIndexOrThrow(DatabaseConstants.SUM_NEG));
            }
        }
        return count;
    }
    
    public static void shareStory(Story story, Context context) {
        if (story == null ) { return; } 
        Intent intent = new Intent(android.content.Intent.ACTION_SEND);
        intent.setType("text/plain");
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_WHEN_TASK_RESET);
        intent.putExtra(Intent.EXTRA_SUBJECT, Html.fromHtml(story.title));
        final String shareString = context.getResources().getString(R.string.share);
        intent.putExtra(Intent.EXTRA_TEXT, String.format(shareString, new Object[] { Html.fromHtml(story.title),
                                                                                       story.permalink }));
        context.startActivity(Intent.createChooser(intent, "Share using"));
    }

    /**
     * An interface usable by callers of this utility class that allows them to receive
     * notification that the async methods here have finihed and may have updated the DB
     * as a result.
     */
    public interface ActionCompletionListener {
        public abstract void actionCompleteCallback(boolean noMoreData);
    }
}
