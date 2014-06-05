package com.newsblur.database;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;

import com.newsblur.util.AppConstants;

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
}
