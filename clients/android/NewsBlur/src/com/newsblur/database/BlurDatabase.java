package com.newsblur.database;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

public class BlurDatabase extends SQLiteOpenHelper {

	public final static String DB_NAME = "blur.db";
	private final static int VERSION = 2;

	public BlurDatabase(Context context) {
		super(context, DB_NAME, null, VERSION);
	}

	@Override
	public void onCreate(SQLiteDatabase db) {
		db.execSQL(DatabaseConstants.FEED_SQL);
		db.execSQL(DatabaseConstants.SOCIAL_FEED_SQL);
		db.execSQL(DatabaseConstants.FOLDER_SQL);
		db.execSQL(DatabaseConstants.USER_SQL);
		db.execSQL(DatabaseConstants.STORY_SQL);
        db.execSQL(DatabaseConstants.READING_SESSION_SQL);
        db.execSQL(DatabaseConstants.STORY_TEXT_SQL);
		db.execSQL(DatabaseConstants.COMMENT_SQL);
		db.execSQL(DatabaseConstants.REPLY_SQL);
		db.execSQL(DatabaseConstants.CLASSIFIER_SQL);
		db.execSQL(DatabaseConstants.SOCIALFEED_STORIES_SQL);
        db.execSQL(DatabaseConstants.STARREDCOUNTS_SQL);
        db.execSQL(DatabaseConstants.ACTION_SQL);
	}
	
	void dropAndRecreateTables() {
		SQLiteDatabase db = getWritableDatabase();
		String drop = "DROP TABLE IF EXISTS ";
		db.execSQL(drop + DatabaseConstants.FEED_TABLE);
		db.execSQL(drop + DatabaseConstants.SOCIALFEED_TABLE);
		db.execSQL(drop + DatabaseConstants.FOLDER_TABLE);
		db.execSQL(drop + DatabaseConstants.STORY_TABLE);
        db.execSQL(drop + DatabaseConstants.READING_SESSION_TABLE);
        db.execSQL(drop + DatabaseConstants.STORY_TEXT_TABLE);
		db.execSQL(drop + DatabaseConstants.USER_TABLE);
		db.execSQL(drop + DatabaseConstants.COMMENT_TABLE);
		db.execSQL(drop + DatabaseConstants.REPLY_TABLE);
		db.execSQL(drop + DatabaseConstants.CLASSIFIER_TABLE);
		db.execSQL(drop + DatabaseConstants.SOCIALFEED_STORY_MAP_TABLE);
		db.execSQL(drop + DatabaseConstants.STARREDCOUNTS_TABLE);
		db.execSQL(drop + DatabaseConstants.ACTION_TABLE);
		
		onCreate(db);
	}

    @Override
    public void onUpgrade(SQLiteDatabase db, int previousVersion, int nextVersion) {
        // note: we drop all tables and recreate any time the schema changes on app upgrade
    }

    public SQLiteDatabase getRO() {
        return getReadableDatabase();
    }

    public SQLiteDatabase getRW() {
        return getWritableDatabase();
    }
}
