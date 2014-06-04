package com.newsblur.database;

import android.content.Context;

import com.newsblur.util.AppConstants;

/**
 * Utility class for executing DB operations on the local, private NB database.
 *
 * It is the intent of this class to be the single location of SQL executed on
 * our DB, replacing the deprecated ContentProvider access pattern.
 */
public class BlurDatabaseHelper {

    private BlurDatabase db;

    public BlurDatabaseHelper(Context context) {
        db = new BlurDatabase(context);
    }

    public void close() {
        db.close();
    }

    public void cleanupStories() {
        String q = "DELETE FROM " + DatabaseConstants.STORY_TABLE + 
                   " WHERE " + DatabaseConstants.STORY_ID + " IN " +
                   "( SELECT " + DatabaseConstants.STORY_ID + " FROM " + DatabaseConstants.STORY_TABLE +
                   " ORDER BY " + DatabaseConstants.STORY_TIMESTAMP + " DESC" +
                   " LIMIT -1 OFFSET " + AppConstants.MAX_STORIES_STORED +
                   ")";
        db.exec(q);
    }
}
