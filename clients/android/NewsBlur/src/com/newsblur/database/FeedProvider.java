package com.newsblur.database;

import java.util.Arrays;

import android.R.string;
import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.UriMatcher;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.text.TextUtils;
import android.util.Log;

import com.newsblur.util.AppConstants;

/**
 * A magic subclass of ContentProvider that enhances calls to the DB for presumably more simple caller syntax.
 *
 * TODO: GET RID OF THIS CLASS.  Per the docs for ContentProfider, one is not required
 *  or recommended for DB access unless sharing data outside of the app, which we do
 *  not.  All DB ops should be done via BlurDatabaseHelper using straightforward, 
 *  standard SQL.  
 */
public class FeedProvider extends ContentProvider {

	public static final String AUTHORITY = "com.newsblur";
	public static final String VERSION = "v1";
	
	public static final Uri CLASSIFIER_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/classifiers/");
	public static final Uri USERS_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/users/");
	public static final Uri COMMENTS_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/comments/");
	public static final Uri REPLIES_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/replies/");
	
	private static final int STORY_COMMENTS = 9;
	private static final int REPLIES = 15;
	private static final int CLASSIFIERS_FOR_FEED = 19;
	private static final int USERS = 21;
	
	private BlurDatabase databaseHelper;

	private static UriMatcher uriMatcher;
	static {
		uriMatcher = new UriMatcher(UriMatcher.NO_MATCH);
		uriMatcher.addURI(AUTHORITY, VERSION + "/classifiers/#/", CLASSIFIERS_FOR_FEED);
		uriMatcher.addURI(AUTHORITY, VERSION + "/comments/", STORY_COMMENTS);
		uriMatcher.addURI(AUTHORITY, VERSION + "/replies/", REPLIES);
		uriMatcher.addURI(AUTHORITY, VERSION + "/users/", USERS);
	}

	@Override
	public int delete(Uri uri, String selection, String[] selectionArgs) {
        synchronized (BlurDatabaseHelper.RW_MUTEX) {
		final SQLiteDatabase db = databaseHelper.getWritableDatabase();
		switch (uriMatcher.match(uri)) {
			case CLASSIFIERS_FOR_FEED:
				return db.delete(DatabaseConstants.CLASSIFIER_TABLE, DatabaseConstants.CLASSIFIER_ID + " = ?", new String[] { uri.getLastPathSegment() });
				
			default:
				return 0;
		}
        }
	}

	@Override
	public String getType(Uri uri) {
		return null;
	}

	@Override
	public Uri insert(Uri uri, ContentValues values) {
        synchronized (BlurDatabaseHelper.RW_MUTEX) {
		final SQLiteDatabase db = databaseHelper.getWritableDatabase();
		Uri resultUri = null;
		switch (uriMatcher.match(uri)) {

		case USERS:
			db.insertWithOnConflict(DatabaseConstants.USER_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			resultUri = uri.buildUpon().appendPath(values.getAsString(DatabaseConstants.USER_USERID)).build();
			break;
			
			// Inserting a classifier for a feed
		case CLASSIFIERS_FOR_FEED:
			values.put(DatabaseConstants.CLASSIFIER_ID, uri.getLastPathSegment());
			db.insertWithOnConflict(DatabaseConstants.CLASSIFIER_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			break;

			// Inserting a comment
		case STORY_COMMENTS:
			db.insertWithOnConflict(DatabaseConstants.COMMENT_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			break;	
		
			// Inserting a reply
		case REPLIES:
			db.insertWithOnConflict(DatabaseConstants.REPLY_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			break;

		case UriMatcher.NO_MATCH:
			Log.e(this.getClass().getName(), "No match found for URI: " + uri.toString());
			break;
		}
		return resultUri;
        }
	}

	@Override
	public boolean onCreate() {
        synchronized (BlurDatabaseHelper.RW_MUTEX) {
		databaseHelper = new BlurDatabase(getContext().getApplicationContext());
        }
		return true;
	}

    /**
     * A simple utility wrapper that lets us log the insanely complex queries used below for debugging.
     */
    class LoggingDatabase {
        SQLiteDatabase mdb; 
        public LoggingDatabase(SQLiteDatabase db) {
            mdb = db;
        }
        public Cursor rawQuery(String sql, String[] selectionArgs) {
            if (AppConstants.VERBOSE_LOG_DB) {
                Log.d(LoggingDatabase.class.getName(), "rawQuery: " + sql);
                Log.d(LoggingDatabase.class.getName(), "selArgs : " + Arrays.toString(selectionArgs));
            }
            Cursor cursor = mdb.rawQuery(sql, selectionArgs);
            if (AppConstants.VERBOSE_LOG_DB) {
                Log.d(LoggingDatabase.class.getName(), "result rows: " + cursor.getCount());
            }
            return cursor;
        }
        public Cursor query(String table, String[] columns, String selection, String[] selectionArgs, String groupBy, String having, String orderBy) {
            if (AppConstants.VERBOSE_LOG_DB) {
                Log.d(LoggingDatabase.class.getName(), "selection: " + selection);
            }
            return mdb.query(table, columns, selection, selectionArgs, groupBy, having, orderBy);
        }
        public void execSQL(String sql) {
            if (AppConstants.VERBOSE_LOG_DB) {
                Log.d(LoggingDatabase.class.getName(), "execSQL: " + sql);
            }
            mdb.execSQL(sql);
        }
        public int update(String table, ContentValues values, String whereClause, String[] whereArgs) {
            return mdb.update(table, values, whereClause, whereArgs);
        }
        public long insertWithOnConflict(String table, String nullColumnHack, ContentValues initialValues, int conflictAlgorithm) {
            return mdb.insertWithOnConflict(table, nullColumnHack, initialValues, conflictAlgorithm);
        }
    }

	@Override
	public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {

		final SQLiteDatabase rdb = databaseHelper.getReadableDatabase();
        final LoggingDatabase db = new LoggingDatabase(rdb);
		switch (uriMatcher.match(uri)) {

		case USERS:
			return db.query(DatabaseConstants.USER_TABLE, projection, selection, selectionArgs, null, null, null);	

			// Query for classifiers for a given feed
		case CLASSIFIERS_FOR_FEED:
			return db.query(DatabaseConstants.CLASSIFIER_TABLE, null, DatabaseConstants.CLASSIFIER_ID + " = ?", new String[] { uri.getLastPathSegment() }, null, null, null);
			
			// Querying for a stories from a feed
		case STORY_COMMENTS:
			if (selectionArgs.length == 1) {
				selection = DatabaseConstants.COMMENT_STORYID + " = ?";
			} else {
				selection = DatabaseConstants.COMMENT_STORYID + " = ? AND " + DatabaseConstants.COMMENT_USERID + " = ?";
			}
			return db.query(DatabaseConstants.COMMENT_TABLE, DatabaseConstants.COMMENT_COLUMNS, selection, selectionArgs, null, null, null);

			// Querying for replies to a comment
		case REPLIES:
			selection = DatabaseConstants.REPLY_COMMENTID+ " = ?";
			return db.query(DatabaseConstants.REPLY_TABLE, DatabaseConstants.REPLY_COLUMNS, selection, selectionArgs, null, null, null);
			
		default:
			throw new UnsupportedOperationException("Unknown URI: " + uri);
		}
	}

	@Override
	public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
        throw new UnsupportedOperationException("Unknown URI: " + uri);
	}

}
