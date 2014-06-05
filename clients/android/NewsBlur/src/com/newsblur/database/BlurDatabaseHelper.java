package com.newsblur.database;

import android.content.ContentValues;
import android.content.Context;
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

import java.util.ArrayList;
import java.util.List;

/**
 * Utility class for executing DB operations on the local, private NB database.
 *
 * It is the intent of this class to be the single location of SQL executed on
 * our DB, replacing the deprecated ContentProvider access pattern.
 */
public class BlurDatabaseHelper {

    private BlurDatabase dbWrapper;
    private SQLiteDatabase dbRO;
    private SQLiteDatabase dbRW;

    public BlurDatabaseHelper(Context context) {
        dbWrapper = new BlurDatabase(context);
        dbRO = dbWrapper.getRO();
        dbRW = dbWrapper.getRW();
    }

    public void close() {
        dbWrapper.close();
    }

    public void cleanupStories() {
        String q = "DELETE FROM " + DatabaseConstants.STORY_TABLE + 
                   " WHERE " + DatabaseConstants.STORY_ID + " IN " +
                   "( SELECT " + DatabaseConstants.STORY_ID + " FROM " + DatabaseConstants.STORY_TABLE +
                   " ORDER BY " + DatabaseConstants.STORY_TIMESTAMP + " DESC" +
                   " LIMIT -1 OFFSET " + AppConstants.MAX_STORIES_STORED +
                   ")";
        dbRW.execSQL(q);
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
        // handle users
        List<ContentValues> userValues = new ArrayList<ContentValues>(apiResponse.users.length);
        for (UserProfile user : apiResponse.users) {
            userValues.add(user.getValues());
        }
        bulkInsertValues(DatabaseConstants.USER_TABLE, userValues);

        // TODO: StoriesResponse can only handle classifiers from /reader/feed, not /reader/river_stories,
        //  so we can't yet make a generic digester

        // handle story content
        List<ContentValues> storyValues = new ArrayList<ContentValues>(apiResponse.stories.length);
        for (Story story : apiResponse.stories) {
            storyValues.add(story.getValues());
        }
        bulkInsertValues(DatabaseConstants.STORY_TABLE, storyValues);
    
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

}
