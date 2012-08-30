package com.newsblur.domain;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import android.content.ContentValues;
import android.database.Cursor;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

public class Classifier {
	
	public static final int AUTHOR = 0, FEED = 1, TITLE = 2, TAG = 3;
	
	@SerializedName("authors")
	public HashMap<String, Integer> authors = new HashMap<String, Integer>();
	
	@SerializedName("titles")
	public HashMap<String, Integer> title = new HashMap<String, Integer>();
	
	@SerializedName("tags")
	public HashMap<String, Integer> tags = new HashMap<String, Integer>();
	
	@SerializedName("feeds")
	public HashMap<String, Integer> feeds = new HashMap<String, Integer>();
	
	public String feedId;
	
	public List<ContentValues> getContentValues() {
		List<ContentValues> valuesList = new ArrayList<ContentValues>();
		for (String key : authors.keySet()) {
			ContentValues authorValues = new ContentValues();
			authorValues.put(DatabaseConstants.CLASSIFIER_ID, feedId);
			authorValues.put(DatabaseConstants.CLASSIFIER_KEY, key);
			authorValues.put(DatabaseConstants.CLASSIFIER_TYPE, AUTHOR);
			authorValues.put(DatabaseConstants.CLASSIFIER_VALUE, authors.get(key));
			
			valuesList.add(authorValues);
		}
		
		for (String key : title.keySet()) {
			ContentValues titleValues = new ContentValues();
			titleValues.put(DatabaseConstants.CLASSIFIER_ID, feedId);
			titleValues.put(DatabaseConstants.CLASSIFIER_KEY, key);
			titleValues.put(DatabaseConstants.CLASSIFIER_TYPE, TITLE);
			titleValues.put(DatabaseConstants.CLASSIFIER_VALUE, title.get(key));
			
			valuesList.add(titleValues);
		}
		
		for (String key : tags.keySet()) {
			ContentValues tagValues = new ContentValues();
			tagValues.put(DatabaseConstants.CLASSIFIER_ID, feedId);
			tagValues.put(DatabaseConstants.CLASSIFIER_KEY, key);
			tagValues.put(DatabaseConstants.CLASSIFIER_TYPE, TAG);
			tagValues.put(DatabaseConstants.CLASSIFIER_VALUE, tags.get(key));
			
			valuesList.add(tagValues);
		}
		
		for (String key : feeds.keySet()) {
			ContentValues feedValues = new ContentValues();
			feedValues.put(DatabaseConstants.CLASSIFIER_ID, feedId);
			feedValues.put(DatabaseConstants.CLASSIFIER_KEY, key);
			feedValues.put(DatabaseConstants.CLASSIFIER_TYPE, FEED);
			feedValues.put(DatabaseConstants.CLASSIFIER_VALUE, feeds.get(key));
			
			valuesList.add(feedValues);
		}
		
		return valuesList;
	}
	
	public static Classifier fromCursor(final Cursor cursor) {
		Classifier classifier = new Classifier();
		
		while (cursor.moveToNext()) {
			String key = cursor.getString(cursor.getColumnIndex(DatabaseConstants.CLASSIFIER_KEY));
			int value = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.CLASSIFIER_VALUE));
			
			switch (cursor.getInt(cursor.getColumnIndex(DatabaseConstants.CLASSIFIER_TYPE))) {
			case AUTHOR:
				classifier.authors.put(key, value);
				break;
			case TITLE:
				classifier.title.put(key, value);	
				break;
			case FEED:
				classifier.feeds.put(key, value);
				break;
			case TAG:
				classifier.tags.put(key, value);
				break;	
			}
		}
		
		return classifier;
	}
	
}
