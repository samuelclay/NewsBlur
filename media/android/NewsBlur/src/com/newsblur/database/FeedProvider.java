package com.newsblur.database;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.UriMatcher;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.text.TextUtils;
import android.util.Log;

public class FeedProvider extends ContentProvider {

	public static final String AUTHORITY = "com.newsblur";
	public static final String VERSION = "v1";
	public static final Uri NEWSBLUR_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION);
	public static final Uri FEEDS_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/feeds/");
	public static final Uri FEED_FOLDER_MAP_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/feedfoldermap/");
	public static final Uri FOLDERS_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/folders/");

	public static final String INTELLIGENCE_ALL = " HAVING SUM(" + DatabaseConstants.FEED_NEGATIVE_COUNT + " + " + DatabaseConstants.FEED_NEUTRAL_COUNT + " + " + DatabaseConstants.FEED_POSITIVE_COUNT + ") > 0 ";
	public static final String INTELLIGENCE_SOME = " HAVING SUM(" + DatabaseConstants.FEED_NEUTRAL_COUNT + " + " + DatabaseConstants.FEED_POSITIVE_COUNT + ") > 0 ";
	public static final String INTELLIGENCE_BEST = " HAVING SUM(" + DatabaseConstants.FEED_POSITIVE_COUNT + ") > 0 ";

	private static final String TAG = "FeedProvider";

	private static final int ALL_FEEDS = 0;
	private static final int SPECIFIC_FEED = 1;
	private static final int ALL_FOLDERS = 2;
	private static final int SPECIFIC_FOLDER = 3;
	private static final int FEED_FOLDER_MAP = 4;
	private static final int SPECIFIC_FEED_FOLDER_MAP = 5;

	private BlurDatabase databaseHelper;

	private static UriMatcher uriMatcher;
	static {
		uriMatcher = new UriMatcher(UriMatcher.NO_MATCH);
		uriMatcher.addURI(AUTHORITY, VERSION + "/feeds/", ALL_FEEDS);
		uriMatcher.addURI(AUTHORITY, VERSION + "/feeds/*/", SPECIFIC_FEED);
		uriMatcher.addURI(AUTHORITY, VERSION + "/feedfoldermap/", FEED_FOLDER_MAP);
		uriMatcher.addURI(AUTHORITY, VERSION + "/feedfoldermap/*/", SPECIFIC_FEED_FOLDER_MAP);
		uriMatcher.addURI(AUTHORITY, VERSION + "/folders/", ALL_FOLDERS);
		uriMatcher.addURI(AUTHORITY, VERSION + "/folders/*/", SPECIFIC_FOLDER);
	}

	@Override
	public int delete(Uri arg0, String arg1, String[] arg2) {
		return 0;
	}

	@Override
	public String getType(Uri uri) {
		return null;
	}

	@Override
	public Uri insert(Uri uri, ContentValues values) {
		final SQLiteDatabase db = databaseHelper.getWritableDatabase();
		Uri resultUri = null;
		switch (uriMatcher.match(uri)) {

		// Inserting a folder
		case ALL_FOLDERS:
			db.beginTransaction();
			final long folderId = db.insertWithOnConflict(DatabaseConstants.FOLDER_TABLE, null, values, SQLiteDatabase.CONFLICT_IGNORE);
			db.setTransactionSuccessful();
			db.endTransaction();
			resultUri = uri.buildUpon().appendPath("" + folderId).build();
			break;

			// Inserting a feed to folder mapping
		case FEED_FOLDER_MAP:
			db.beginTransaction();
			db.insertWithOnConflict(DatabaseConstants.FEED_FOLDER_MAP_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			db.setTransactionSuccessful();
			db.endTransaction();
			resultUri = uri.buildUpon().appendPath(values.getAsString(DatabaseConstants.FEED_FOLDER_FOLDER_NAME)).build();
			break;

			// Inserting a feed
		case ALL_FEEDS:
			db.beginTransaction();
			db.insertWithOnConflict(DatabaseConstants.FEED_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			db.setTransactionSuccessful();
			db.endTransaction();
			resultUri = uri.buildUpon().appendPath(values.getAsString(DatabaseConstants.FEED_ID)).build();
			break;

			// Inserting a story	
		case SPECIFIC_FEED:
			db.beginTransaction();
			db.insertWithOnConflict(DatabaseConstants.STORY_TABLE, null, values, SQLiteDatabase.CONFLICT_REPLACE);
			db.setTransactionSuccessful();
			db.endTransaction();
			break;			
		case UriMatcher.NO_MATCH:
			Log.d(TAG, "No match found for URI: " + uri.toString());
			break;
		}
		db.close();
		return resultUri;
	}

	@Override
	public boolean onCreate() {
		Log.d(TAG, "Creating provider and database.");
		databaseHelper = new BlurDatabase(getContext().getApplicationContext());
		return true;
	}

	@Override
	public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
		final SQLiteDatabase db = databaseHelper.getReadableDatabase();
		Cursor cursor = null;
		switch (uriMatcher.match(uri)) {

		// Query for all feeds (by default only return those that have unread items in them)
		case ALL_FEEDS:
			cursor = db.rawQuery("SELECT " + TextUtils.join(",", DatabaseConstants.FEED_COLUMNS) + " FROM " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + 
					" INNER JOIN " + DatabaseConstants.FEED_TABLE + 
					" ON " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID + " = " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "." + DatabaseConstants.FEED_FOLDER_FEED_ID +
					" WHERE (" + DatabaseConstants.FEED_NEGATIVE_COUNT + " + " + DatabaseConstants.FEED_NEUTRAL_COUNT + " + " + DatabaseConstants.FEED_POSITIVE_COUNT + ") > 0 " +
					" ORDER BY " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_TITLE + " COLLATE NOCASE", selectionArgs);
			break;

			// Querying for a specific
		case SPECIFIC_FEED:
			selection = DatabaseConstants.FEED_ID + " = ?";
			selectionArgs = new String[] { uri.getLastPathSegment() };
			cursor = db.query(DatabaseConstants.FEED_TABLE, projection, selection, selectionArgs, null, null, sortOrder);
			break;

			// Query for feeds with no folder mapping	
		case FEED_FOLDER_MAP:
			String nullFolderQuery = "SELECT " + TextUtils.join(",", DatabaseConstants.FEED_COLUMNS) + " FROM " + DatabaseConstants.FEED_TABLE + 
			" LEFT JOIN " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + 
			" ON " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID + " = " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "."  + DatabaseConstants.FEED_FOLDER_FEED_ID +
			" WHERE " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "." + DatabaseConstants.FEED_FOLDER_FOLDER_NAME + " IS NULL " +
			" GROUP BY " + DatabaseConstants.FEED_TABLE+ "." + DatabaseConstants.FEED_ID;

			StringBuilder nullFolderBuilder = new StringBuilder();
			nullFolderBuilder.append(nullFolderQuery);
			if (selectionArgs != null && selectionArgs.length > 0) {
				nullFolderBuilder.append(selectionArgs[0]);
			}
			nullFolderBuilder.append(" ORDER BY " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_TITLE + " COLLATE NOCASE");
			cursor = db.rawQuery(nullFolderBuilder.toString(), null);
			break;

			// Querying for feeds for a given folder	
		case SPECIFIC_FEED_FOLDER_MAP:
			selection = DatabaseConstants.FOLDER_ID + " = ?";
			String[] folderArguments = new String[] { uri.getLastPathSegment() };

			String query = "SELECT " + TextUtils.join(",", DatabaseConstants.FEED_COLUMNS) + " FROM " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + 
			" INNER JOIN " + DatabaseConstants.FEED_TABLE + 
			" ON " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID + " = " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "." + DatabaseConstants.FEED_FOLDER_FEED_ID +
			" WHERE " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "." + DatabaseConstants.FEED_FOLDER_FOLDER_NAME + " = ? " +
			" GROUP BY " + DatabaseConstants.FEED_TABLE+ "." + DatabaseConstants.FEED_ID;

			StringBuilder builder = new StringBuilder();
			builder.append(query);
			if (selectionArgs != null && selectionArgs.length > 0) {
				builder.append(selectionArgs[0]);
			}
			builder.append(" ORDER BY " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_TITLE + " COLLATE NOCASE");
			cursor = db.rawQuery(builder.toString(), folderArguments);
			break;

			// Querying for all folders with unread items
		case ALL_FOLDERS:
			String folderQuery = "SELECT " + TextUtils.join(",", DatabaseConstants.FOLDER_COLUMNS) + " FROM " + DatabaseConstants.FEED_FOLDER_MAP_TABLE  +
			" LEFT JOIN " + DatabaseConstants.FOLDER_TABLE + 
			" ON " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "." + DatabaseConstants.FEED_FOLDER_FOLDER_NAME + " = " + DatabaseConstants.FOLDER_TABLE + "." + DatabaseConstants.FOLDER_NAME +
			" LEFT JOIN " + DatabaseConstants.FEED_TABLE + 
			" ON " + DatabaseConstants.FEED_TABLE + "." + DatabaseConstants.FEED_ID + " = " + DatabaseConstants.FEED_FOLDER_MAP_TABLE + "."  + DatabaseConstants.FEED_FOLDER_FEED_ID + 
			" GROUP BY " + DatabaseConstants.FOLDER_TABLE + "." + DatabaseConstants.FOLDER_NAME;

			StringBuilder folderBuilder = new StringBuilder();
			folderBuilder.append(folderQuery);
			if (selectionArgs != null && selectionArgs.length > 0) {
				folderBuilder.append(selectionArgs[0]);
			}
			folderBuilder.append(" ORDER BY ");
			folderBuilder.append(DatabaseConstants.FOLDER_TABLE + "." + DatabaseConstants.FOLDER_NAME + " COLLATE NOCASE");
			cursor = db.rawQuery(folderBuilder.toString(), null);
			break;
		}
		return cursor;
	}

	@Override
	public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
		// TODO Auto-generated method stub
		return 0;
	}


}
