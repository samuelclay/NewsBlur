package com.newsblur.domain;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import android.content.ContentValues;
import android.database.Cursor;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

public class Classifier implements Serializable {
	
	private static final long serialVersionUID = 8958319817246110753L;

	public static final int AUTHOR = 0, FEED = 1, TITLE = 2, TAG = 3;
	public static final int LIKE = 1, DISLIKE = -1, CLEAR_DISLIKE = 3, CLEAR_LIKE = 4;

    // these pre/post constants are used to build the 16 possible parameter names accepted by the API
    // when updating intel
    private static final String AUTHOR_POSTFIX = "author";
    private static final String FEED_POSTFIX = "feed";
    private static final String TITLE_POSTFIX = "title";
    private static final String TAG_POSTFIX = "tag";
    private static final String LIKE_PREFIX = "like_";
    private static final String DISLIKE_PREFIX = "dislike_";
    private static final String CLEAR_LIKE_PREFIX = "remove_like_";
    private static final String CLEAR_DISLIKE_PREFIX = "remove_dislike_";
	
	@SerializedName("authors")
	public HashMap<String, Integer> authors = new HashMap<String, Integer>();
	
	@SerializedName("titles")
	public HashMap<String, Integer> title = new HashMap<String, Integer>();
	
	@SerializedName("tags")
	public HashMap<String, Integer> tags = new HashMap<String, Integer>();
	
	@SerializedName("feeds")
	public HashMap<String, Integer> feeds = new HashMap<String, Integer>();

    // not vended by API, but all classifiers are received in the context of a feed, where this is set. needs to
    // be set manually when unfrozen.
    public String feedId;
	
    public ValueMultimap getAPITuples() {
        ValueMultimap values = new ValueMultimap();
        for (Map.Entry<String,Integer> entry : authors.entrySet()) {
            values.put(buildAPITupleKey(entry.getValue(), AUTHOR_POSTFIX), entry.getKey());
        }
        for (Map.Entry<String,Integer> entry : title.entrySet()) {
            values.put(buildAPITupleKey(entry.getValue(), TITLE_POSTFIX), entry.getKey());
        }
        for (Map.Entry<String,Integer> entry : tags.entrySet()) {
            values.put(buildAPITupleKey(entry.getValue(), TAG_POSTFIX), entry.getKey());
        }
        for (Map.Entry<String,Integer> entry : feeds.entrySet()) {
            values.put(buildAPITupleKey(entry.getValue(), FEED_POSTFIX), entry.getKey());
        }
        return values;
    }

    private String buildAPITupleKey(int action, String postfix) {
        switch (action) {
            case LIKE:
                return (LIKE_PREFIX + postfix);
            case DISLIKE:
                return (DISLIKE_PREFIX + postfix);
            case CLEAR_LIKE:
                return (CLEAR_LIKE_PREFIX + postfix);
            case CLEAR_DISLIKE:
                return (CLEAR_DISLIKE_PREFIX + postfix);
            default:
                throw new IllegalArgumentException("invalid classifier action type");
        }
    }
	
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
