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
import com.newsblur.activity.NbActivity;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.Story;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;

public class FeedUtils {

    private static BlurDatabaseHelper dbHelper;

    public static void offerDB(BlurDatabaseHelper _dbHelper) {
        if (_dbHelper.isOpen()) {
            dbHelper = _dbHelper;
        }
    }

    private static void triggerSync(Context c) {
        Intent i = new Intent(c, NBSyncService.class);
        c.startService(i);
    }

	private static void setStorySaved(final Story story, final boolean saved, final Context context, final APIManager apiManager) {
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

                NbActivity.updateAllActivities();
            }
        }.execute();
	}

	public static void saveStory(final Story story, final Context context, final APIManager apiManager) {
        setStorySaved(story, true, context, apiManager);
    }

	public static void unsaveStory(final Story story, final Context context, final APIManager apiManager) {
        setStorySaved(story, false, context, apiManager);
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

    public static void clearReadingSession(final Context context) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                try {
                    dbHelper.clearReadingSession();
                } catch (Exception e) {
                    ; // this one call can evade the on-upgrade DB wipe and throw exceptions
                }
                NBSyncService.resetFeeds();
                return null;
            }
        }.execute();
    }

    public static void markStoryUnread(final Story story, final Context context) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                setStoryReadState(story, context, false);
                return null;
            }
        }.execute();
    }

    public static void markStoryAsRead(final Story story, final Context context) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                setStoryReadState(story, context, true);
                return null;
            }
        }.execute();
    }

    private static void setStoryReadState(Story story, Context context, boolean read) {
        if (story.read == read) { return; }

        // it is imperative that we are idempotent.  query the DB for a fresh copy of the story
        // to ensure it isn't already in the requested state.  if so, do not update feed counts
        Cursor cursor = dbHelper.getStory(story.storyHash);
        if (cursor.getCount() < 1) {
            Log.w(FeedUtils.class.getName(), "can't mark story as read, not found in DB: " + story.id);
            return;
        }
        Story freshStory = Story.fromCursor(cursor);
        cursor.close();
        if (freshStory.read == read) { return; }

        // update the local object to show as read before DB is touched
        story.read = read;

        // update unread state and unread counts in the local DB
        dbHelper.setStoryReadState(story, read);

        // tell the sync service we need to mark read
        dbHelper.enqueueActionStoryRead(story.storyHash, read);
        triggerSync(context);
    }

    public static void markFeedsRead(final FeedSet fs, final Long olderThan, final Long newerThan, final Context context) {
        new AsyncTask<Void, Void, Void>() {
            @Override
            protected Void doInBackground(Void... arg) {
                dbHelper.enqueueActionFeedRead(fs, olderThan, newerThan);
                dbHelper.markFeedsRead(fs, olderThan, newerThan);
                triggerSync(context);
                return null;
            }
        }.execute();
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

    public static FeedSet feedSetFromFolderName(String folderName, Context context) {
        Set<String> feedIds = dbHelper.getFeedsForFolder(folderName);
        return FeedSet.folder(folderName, feedIds);
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
