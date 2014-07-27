package com.newsblur.database;

import android.content.ContentValues;
import android.content.Context;
import android.content.Loader;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.text.TextUtils;
import android.util.Log;

import com.newsblur.domain.Classifier;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Feed;
import com.newsblur.domain.FeedResult;
import com.newsblur.domain.Reply;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserProfile;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;

import java.util.ArrayList;
import java.util.List;

/**
 * Utility class for executing DB operations on the local, private NB database.
 *
 * It is the intent of this class to be the single location of SQL executed on
 * our DB, replacing the deprecated ContentProvider access pattern.
 */
public class BlurDatabaseHelper {

    private Context context;
    private BlurDatabase dbWrapper;
    private SQLiteDatabase dbRO;
    private SQLiteDatabase dbRW;

    public BlurDatabaseHelper(Context context) {
        this.context = context;
        dbWrapper = new BlurDatabase(context);
        dbRO = dbWrapper.getRO();
        dbRW = dbWrapper.getRW();
    }

    public void close() {
        dbWrapper.close();
    }

    public void cleanupStories(boolean keepOldStories) {
        String q1 = "SELECT " + DatabaseConstants.FEED_ID +
                    " FROM " + DatabaseConstants.FEED_TABLE;
        Cursor c = dbRO.rawQuery(q1, null);
        List<String> feedIds = new ArrayList<String>(c.getCount());
        while (c.moveToNext()) {
           feedIds.add(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.FEED_ID)));
        }
        c.close();
        for (String feedId : feedIds) {
            String q = "DELETE FROM " + DatabaseConstants.STORY_TABLE + 
                       " WHERE " + DatabaseConstants.STORY_ID + " IN " +
                       "( SELECT " + DatabaseConstants.STORY_ID + " FROM " + DatabaseConstants.STORY_TABLE +
                       " WHERE " + DatabaseConstants.STORY_READ + " = 1" +
                       " AND " + DatabaseConstants.STORY_FEED_ID + " = " + feedId +
                       " ORDER BY " + DatabaseConstants.STORY_TIMESTAMP + " DESC" +
                       " LIMIT -1 OFFSET " + (keepOldStories ? AppConstants.MAX_READ_STORIES_STORED : 0) +
                       ")";
            dbRW.execSQL(q);
        }
    }

    public void cleanupFeedsFolders() {
        dbRW.delete(DatabaseConstants.FEED_TABLE, null, null);
        dbRW.delete(DatabaseConstants.FOLDER_TABLE, null, null);
        dbRW.delete(DatabaseConstants.FEED_FOLDER_MAP_TABLE, null, null);
    }

    private void bulkInsertValues(String table, List<ContentValues> valuesList) {
        if (valuesList.size() < 1) return;
        dbRW.beginTransaction();
        try {
            for(ContentValues values: valuesList) {
                dbRW.insertWithOnConflict(table, null, values, SQLiteDatabase.CONFLICT_REPLACE);
            }
            dbRW.setTransactionSuccessful();
        } finally {
            dbRW.endTransaction();
        }
    }

    public void insertFeedsFolders(List<ContentValues> feedValues,
                                   List<ContentValues> folderValues,
                                   List<ContentValues> ffmValues,
                                   List<ContentValues> socialFeedValues) {
        bulkInsertValues(DatabaseConstants.FEED_TABLE, feedValues);
        bulkInsertValues(DatabaseConstants.FOLDER_TABLE, folderValues);
        bulkInsertValues(DatabaseConstants.FEED_FOLDER_MAP_TABLE, ffmValues);
        bulkInsertValues(DatabaseConstants.SOCIALFEED_TABLE, socialFeedValues);
    }

    public void updateStarredStoriesCount(int count) {
        ContentValues values = new ContentValues();
        values.put(DatabaseConstants.STARRED_STORY_COUNT_COUNT, count);
        // this DB just has one row and one column.  blow it away and replace it.
        dbRW.delete(DatabaseConstants.STARRED_STORY_COUNT_TABLE, null, null);
        dbRW.insert(DatabaseConstants.STARRED_STORY_COUNT_TABLE, null, values);
    }

    public List<String> getStoryHashesForFeed(String feedId) {
        String q = "SELECT " + DatabaseConstants.STORY_HASH + 
                   " FROM " + DatabaseConstants.STORY_TABLE +
                   " WHERE " + DatabaseConstants.STORY_FEED_ID + " = ?";
        Cursor c = dbRO.rawQuery(q, new String[]{feedId});
        List<String> hashes = new ArrayList<String>(c.getCount());
        while (c.moveToNext()) {
           hashes.add(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.STORY_HASH)));
        }
        c.close();
        return hashes;
    }

    public List<String> getUnreadStoryHashes() {
        String q = "SELECT " + DatabaseConstants.STORY_HASH + 
                   " FROM " + DatabaseConstants.STORY_TABLE +
                   " WHERE " + DatabaseConstants.STORY_READ + " = 0" ;
        Cursor c = dbRO.rawQuery(q, null);
        List<String> hashes = new ArrayList<String>(c.getCount());
        while (c.moveToNext()) {
           hashes.add(c.getString(c.getColumnIndexOrThrow(DatabaseConstants.STORY_HASH)));
        }
        c.close();
        return hashes;
    }

    public void insertStories(StoriesResponse apiResponse) {
        // to insert classifiers, we need to determine the feed ID of the stories in this
        // response, so sniff one out.
        String impliedFeedId = null;

        // handle users
        if (apiResponse.users != null) {
            List<ContentValues> userValues = new ArrayList<ContentValues>(apiResponse.users.length);
            for (UserProfile user : apiResponse.users) {
                userValues.add(user.getValues());
            }
            bulkInsertValues(DatabaseConstants.USER_TABLE, userValues);
        }

        // handle supplemental feed data that may have been included (usually in social requests)
        if (apiResponse.feeds != null) {
            List<ContentValues> feedValues = new ArrayList<ContentValues>(apiResponse.feeds.size());
            for (Feed feed : apiResponse.feeds) {
                feedValues.add(feed.getValues());
            }
            bulkInsertValues(DatabaseConstants.FEED_TABLE, feedValues);
        }

        // handle story content
        List<ContentValues> storyValues = new ArrayList<ContentValues>(apiResponse.stories.length);
        List<ContentValues> socialStoryValues = new ArrayList<ContentValues>();
        for (Story story : apiResponse.stories) {
            ContentValues values = story.getValues();
            // the basic columns are fine for the stories table
            storyValues.add(values);
            // if a story was shared by a user, also insert it into the social table under their userid, too
            for (String sharedUserId : story.sharedUserIds) {
                ContentValues socialValues = new ContentValues();
                socialValues.put(DatabaseConstants.SOCIALFEED_STORY_USER_ID, sharedUserId);
                socialValues.put(DatabaseConstants.SOCIALFEED_STORY_STORYID, values.getAsString(DatabaseConstants.STORY_ID));
                socialStoryValues.add(socialValues);
            }
            impliedFeedId = story.feedId;
        }
        bulkInsertValues(DatabaseConstants.STORY_TABLE, storyValues);
        bulkInsertValues(DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE, socialStoryValues);

        // handle classifiers
        // NOTE: only handles top-level classifiers, which only show up for single-feed requests
        if (apiResponse.classifiers != null) {
            List<ContentValues> classifierValues = apiResponse.classifiers.getContentValues();
            for (ContentValues values : classifierValues) {
                values.put(DatabaseConstants.CLASSIFIER_ID, impliedFeedId);
            }
            dbRW.delete(DatabaseConstants.CLASSIFIER_TABLE, DatabaseConstants.CLASSIFIER_ID + " = ?", new String[] { impliedFeedId });
            bulkInsertValues(DatabaseConstants.CLASSIFIER_TABLE, classifierValues);
        }

        // handle comments
        List<ContentValues> commentValues = new ArrayList<ContentValues>();
        List<ContentValues> replyValues = new ArrayList<ContentValues>();
        for (Story story : apiResponse.stories) {
            for (Comment comment : story.publicComments) {
                comment.storyId = story.id;
                comment.id = TextUtils.concat(story.id, story.feedId, comment.userId).toString();
                commentValues.add(comment.getValues());
                for (Reply reply : comment.replies) {
                    reply.commentId = comment.id;
                    replyValues.add(reply.getValues());
                }
            }
            for (Comment comment : story.friendsComments) {
                comment.storyId = story.id;
                comment.id = TextUtils.concat(story.id, story.feedId, comment.userId).toString();
                commentValues.add(comment.getValues());
                for (Reply reply : comment.replies) {
                    reply.commentId = comment.id;
                    replyValues.add(reply.getValues());
                }
            }
        }
        bulkInsertValues(DatabaseConstants.COMMENT_TABLE, commentValues);
        bulkInsertValues(DatabaseConstants.REPLY_TABLE, replyValues);
    }

    public void markStoryHashesRead(List<String> hashes) {
        // NOTE: attempting to wrap these updates in a transaction for speed makes them silently fail
        for (String hash : hashes) {
            ContentValues values = new ContentValues();
            values.put(DatabaseConstants.STORY_READ, true);
            dbRW.update(DatabaseConstants.STORY_TABLE, values, DatabaseConstants.STORY_HASH + " = ?", new String[]{hash});
        }
    }

    public int getFeedUnreadCount(String feedId, int readingState) {
        // calculate the unread count both from the feeds table and the stories table. If
        // they disagree, use the maximum value seen.
        int countFromFeedsTable = 0;
        int countFromStoriesTable = 0;

        // note we have to select the whole story object so we can get all they flavours of unread count and do math on them
        String q1 = "SELECT " + TextUtils.join(",", DatabaseConstants.FEED_COLUMNS) + 
                    " FROM " + DatabaseConstants.FEED_TABLE +
                    " WHERE " +  DatabaseConstants.FEED_ID + "= ?";
        Cursor c1 = dbRO.rawQuery(q1, new String[]{feedId});
        if (c1.getCount() > 0) {
            Feed feed = Feed.fromCursor(c1);
            countFromFeedsTable = FeedUtils.getFeedUnreadCount(feed, readingState);
        }
        c1.close();

        // note we can't select count(*) because the actual story state columns are virtual
        String q2 = "SELECT " + TextUtils.join(",", DatabaseConstants.STORY_COLUMNS) + " FROM " + DatabaseConstants.STORY_TABLE +
                    " WHERE " +  DatabaseConstants.STORY_FEED_ID + "= ?" +
                    " AND " + DatabaseConstants.getStorySelectionFromState(readingState) +
                    " AND " + DatabaseConstants.STORY_READ + " = 0";
        Cursor c2 = dbRO.rawQuery(q2, new String[]{feedId});
        countFromStoriesTable = c2.getCount();
        c2.close();

        return Math.max(countFromFeedsTable, countFromStoriesTable);
    }

    public Loader<Cursor> getSavedStoriesLoader() {
        return new QueryCursorLoader(context) {
            protected Cursor createCursor() {return getSavedStoriesCursor();}
        };
    }

    public Cursor getSavedStoriesCursor() {
        String q = DatabaseConstants.MULTIFEED_STORIES_QUERY_BASE + 
                   " WHERE " + DatabaseConstants.STORY_STARRED + " = 1" +
                   " ORDER BY " + DatabaseConstants.STARRED_STORY_ORDER;
        return dbRO.rawQuery(q, null);
    }

}
