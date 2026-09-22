package com.newsblur.database;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

public class BlurDatabase extends SQLiteOpenHelper {

	public final static String DB_NAME = "blur.db";
	static final int VERSION = 9;

	public BlurDatabase(Context context) {
		this(context, DB_NAME);
	}

	BlurDatabase(Context context, String dbName) {
		super(context, dbName, null, VERSION);
	}

	@Override
	public void onCreate(SQLiteDatabase db) {
		db.execSQL(DatabaseConstants.FEED_SQL);
		db.execSQL(DatabaseConstants.SOCIAL_FEED_SQL);
		db.execSQL(DatabaseConstants.FOLDER_SQL);
		db.execSQL(DatabaseConstants.USER_SQL);
		db.execSQL(DatabaseConstants.STORY_SQL);
        ClusterReadStore.createTables(db);
        db.execSQL(DatabaseConstants.READING_SESSION_SQL);
        db.execSQL(DatabaseConstants.STORY_TEXT_SQL);
		db.execSQL(DatabaseConstants.COMMENT_SQL);
		db.execSQL(DatabaseConstants.REPLY_SQL);
		db.execSQL(DatabaseConstants.CLASSIFIER_SQL);
		db.execSQL(DatabaseConstants.SOCIALFEED_STORIES_SQL);
        db.execSQL(DatabaseConstants.STARREDCOUNTS_SQL);
        db.execSQL(DatabaseConstants.SAVED_SEARCH_SQL);
        db.execSQL(DatabaseConstants.ACTION_SQL);
        db.execSQL(DatabaseConstants.NOTIFY_DISMISS_SQL);
        db.execSQL(DatabaseConstants.FEED_TAGS_SQL);
        db.execSQL(DatabaseConstants.FEED_AUTHORS_SQL);
        db.execSQL(DatabaseConstants.SYNC_METADATA_SQL);
        db.execSQL(DatabaseConstants.CUSTOM_ICON_SQL);
	}

	@Override
	public void onOpen(SQLiteDatabase db) {
		super.onOpen(db);
		db.enableWriteAheadLogging();
	}

	void dropAndRecreateTables() {
		SQLiteDatabase db = getWritableDatabase();
		dropAndRecreateTables(db);
	}

	private void dropAndRecreateTables(SQLiteDatabase db) {
		ClusterReadStore.dropTables(db);
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
		db.execSQL(drop + DatabaseConstants.SAVED_SEARCH_TABLE);
		db.execSQL(drop + DatabaseConstants.ACTION_TABLE);
        db.execSQL(drop + DatabaseConstants.NOTIFY_DISMISS_TABLE);
        db.execSQL(drop + DatabaseConstants.FEED_TAGS_TABLE);
        db.execSQL(drop + DatabaseConstants.FEED_AUTHORS_TABLE);
        db.execSQL(drop + DatabaseConstants.SYNC_METADATA_TABLE);
        db.execSQL(drop + DatabaseConstants.CUSTOM_ICON_TABLE);

		onCreate(db);
	}

    @Override
    public void onUpgrade(SQLiteDatabase db, int previousVersion, int nextVersion) {
        if (previousVersion >= 6 && previousVersion < 9) {
            // Folder.java reconstructs segment keys from the cached parent list. Display
            // paths can collide when a folder title contains the hierarchy separator.
            db.execSQL("ALTER TABLE " + DatabaseConstants.FOLDER_TABLE + " RENAME TO folders_legacy");
            db.execSQL(DatabaseConstants.FOLDER_SQL);
            try (android.database.Cursor cursor = db.query("folders_legacy", null, null, null, null, null, null)) {
                while (cursor.moveToNext()) {
                    db.insertOrThrow(DatabaseConstants.FOLDER_TABLE, null,
                            com.newsblur.domain.Folder.fromCursor(cursor).getValues());
                }
            }
            db.execSQL("DROP TABLE folders_legacy");
            if (previousVersion < 8) {
                // ClusterReadStore.kt backfills membership without replacing cached stories or queued actions.
                ClusterReadStore.createTables(db);
                ClusterReadStore.backfill(db);
            }
            return;
        }
        dropAndRecreateTables(db);
    }

    @Override
    public void onDowngrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        dropAndRecreateTables(db);
    }

    public SQLiteDatabase getRO() {
        return getReadableDatabase();
    }

    public SQLiteDatabase getRW() {
        return getWritableDatabase();
    }
}
