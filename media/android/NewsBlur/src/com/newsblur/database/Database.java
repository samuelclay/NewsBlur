package com.newsblur.database;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteDatabase.CursorFactory;
import android.database.sqlite.SQLiteOpenHelper;
import android.util.Log;

public class Database extends SQLiteOpenHelper {

	private final String TEXT = " text";
	private final String INTEGER = " integer";
	private final static String TAG = "DatabaseHelper";

	
	public Database(Context context, String name, CursorFactory factory, int version) {
		super(context, name, factory, version);
		Log.d(TAG, "Initiating database");
	}
	
	private final String FOLDER_SQL = "CREATE TABLE " + Constants.FOLDER_TABLE + " IF NOT EXISTS (" +
		Constants.FOLDER_ID + TEXT + ", " +
		Constants.FOLDER_NAME + TEXT + 
		")";
	
	private final String FEED_SQL = "CREATE TABLE " + Constants.FEED_TABLE + " IF NOT EXISTS (" +
		Constants.FEED_ID + INTEGER + ", " +
		Constants.FEED_ACTIVE + TEXT + ", " +
		Constants.FEED_ADDRESS + TEXT + ", " + 
		Constants.FEED_FAVICON_COLOUR + TEXT + ", " +
		Constants.FEED_FAVICON_FADE + TEXT + ", " + 
		Constants.FEED_LINK + TEXT + ", " + 
		Constants.FEED_SUBSCRIBERS + TEXT + ", " +
		Constants.FEED_TITLE + TEXT + ", " + 
		Constants.FEED_UPDATED_SECONDS +
		")";
	
	private final String STORY_SQL = "CREATE TABLE " + Constants.STORY_TABLE + " IF NOT EXISTS (" +
		Constants.STORY_AUTHORS + TEXT + ", " +
		Constants.STORY_CONTENT + TEXT + ", " +
		Constants.STORY_DATE + TEXT + ", " +
		Constants.STORY_FEED_ID + INTEGER + ", " +
		Constants.STORY_ID + TEXT + ", " +
		Constants.STORY_INTELLIGENCE_AUTHORS + INTEGER + ", " +
		Constants.STORY_INTELLIGENCE_FEED + INTEGER + ", " + 
		Constants.STORY_INTELLIGENCE_TAGS + INTEGER + ", " +
		Constants.STORY_INTELLIGENCE_TITLE + INTEGER + ", " +
		Constants.STORY_PERMALINK + TEXT + ", " + 
		Constants.STORY_READ + TEXT + ", " +
		Constants.STORY_TITLE + TEXT + 
		")";
	
	private final String CLASSIFIER_SQL = "CREATE TABLE " + Constants.CLASSIFIER_TABLE + " IF NOT EXISTS (" +
		Constants.CLASSIFIER_ID + TEXT + ", " +
		Constants.CLASSIFIER_KEY + TEXT + ", " + 
		Constants.CLASSIFIER_TYPE + TEXT + ", " +
		Constants.CLASSIFIER_VALUE + TEXT +
		")";
	
	@Override
	public void onCreate(SQLiteDatabase db) {
		db.execSQL(FEED_SQL);
		db.execSQL(FOLDER_SQL);
		db.execSQL(STORY_SQL);
		db.execSQL(CLASSIFIER_SQL);
	}

	@Override
	public void onUpgrade(SQLiteDatabase db, int previousVersion, int nextVersion) {
		// TODO: Handle DB version updates using switch 
	}

}
