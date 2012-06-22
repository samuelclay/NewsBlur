package com.newsblur.database;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.UriMatcher;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.net.Uri;
import android.util.Log;

public class FeedProvider extends ContentProvider {

	public static final String AUTHORITY = "com.newsblur";
	public static final String VERSION = "v1";
	public static final Uri NEWSBLUR_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION);
	public static final Uri FEEDS_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/feeds/");
	public static final Uri FOLDERS_URI = Uri.parse("content://" + AUTHORITY + "/" + VERSION + "/folders/");
	
	private static final String TAG = "FeedProvider";
	
	private static final int ALL_FEEDS = 0;
	private static final int SPECIFIC_FEED = 1;
	private static final int ALL_FOLDERS = 2;
	private static final int SPECIFIC_FOLDER = 3;
	
	private BlurDatabase databaseHelper;
	
	private static UriMatcher uriMatcher;
	static {
		uriMatcher = new UriMatcher(UriMatcher.NO_MATCH);
		uriMatcher.addURI(AUTHORITY, VERSION + "/feeds/", ALL_FEEDS);
		uriMatcher.addURI(AUTHORITY, VERSION + "/feeds/*/", SPECIFIC_FEED);
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
				db.insert(Constants.FOLDER_TABLE, null, values);
				db.setTransactionSuccessful();
				db.endTransaction();
				resultUri = uri.buildUpon().appendPath(values.getAsString(Constants.FOLDER_ID)).build();
			break;
		
			// Inserting a feed
			case ALL_FEEDS:
				db.beginTransaction();
				db.insert(Constants.FEED_TABLE, null, values);
				db.setTransactionSuccessful();
				db.endTransaction();
				resultUri = uri.buildUpon().appendPath(values.getAsString(Constants.FEED_ID)).build();
				break;
	
			// Inserting a story	
			case SPECIFIC_FEED:
				db.beginTransaction();
				db.insert(Constants.STORY_TABLE, null, values);
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
		databaseHelper = new BlurDatabase(getContext());
		return true;
	}

	@Override
	public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
		final SQLiteDatabase db = databaseHelper.getReadableDatabase();
		Cursor cursor = null;
		switch (uriMatcher.match(uri)) {
			// Inserting a feed
			case ALL_FEEDS:
				cursor = db.rawQuery(Constants.FEED_TABLE, null);
				break;
			// Inserting a story	
			case SPECIFIC_FEED:
				selection = Constants.FEED_ID + " = ?";
				selectionArgs = new String[] { uri.getLastPathSegment() };
				cursor = db.query(Constants.FEED_TABLE, projection, selection, selectionArgs, null, null, sortOrder);
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
