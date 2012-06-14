package com.newsblur.database;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.UriMatcher;
import android.database.Cursor;
import android.net.Uri;

public class FeedContentProvider extends ContentProvider {

	public static final String PROVIDER_URI = "com.newsblur.android";
	
	@Override
	public int delete(Uri arg0, String arg1, String[] arg2) {
		// TODO Auto-generated method stub
		return 0;
	}

	@Override
	public String getType(Uri arg0) {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public Uri insert(Uri uri, ContentValues values) {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public boolean onCreate() {
		// TODO Auto-generated method stub
		return false;
	}

	@Override
	public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs, String sortOrder) {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
		// TODO Auto-generated method stub
		return 0;
	}
	
	private static final UriMatcher uriMatcher;
	private static final int FOLDERS = 0, 
		FOLDER_ID = 1, 
		FEEDS = 2,
		FEED_ID = 3,
		STORIES = 4,
		STORY_ID = 5;
	static {
	   uriMatcher = new UriMatcher(UriMatcher.NO_MATCH);
	   uriMatcher.addURI(PROVIDER_URI, "folders", FOLDERS);
	   uriMatcher.addURI(PROVIDER_URI, "folders/#", FOLDER_ID);
	   uriMatcher.addURI(PROVIDER_URI, "feeds", FEEDS);
	   uriMatcher.addURI(PROVIDER_URI, "feeds/#", FEED_ID);
	   uriMatcher.addURI(PROVIDER_URI, "stories", STORIES);
	   uriMatcher.addURI(PROVIDER_URI, "stories/#", STORY_ID);
	}

}
