package com.newsblur.database;

import android.provider.BaseColumns;

public class Constants {
	
	public static String FOLDER_TABLE = "folders";
	public static String FOLDER_ID = BaseColumns._ID;
	public static String FOLDER_NAME = "folder_name";
	
	public static String FEED_TABLE = "feeds";
	public static String FEED_ID = BaseColumns._ID;
	public static String FEED_TITLE = "feed_name";
	public static String FEED_LINK = "link";
	public static String FEED_ADDRESS = "address";
	public static String FEED_SUBSCRIBERS = "subscribers";
	public static String FEED_UPDATED_SECONDS = "updated_seconds";
	public static String FEED_FAVICON_FADE = "favicon_fade";
	public static String FEED_FAVICON_COLOUR = "favicon_colour";
	public static String FEED_ACTIVE = "active";
	
	public static String CLASSIFIER_TABLE = "classifiers";
	public static String CLASSIFIER_ID = BaseColumns._ID;
	public static String CLASSIFIER_TYPE = "type";
	public static String CLASSIFIER_KEY = "key";
	public static String CLASSIFIER_VALUE = "value";
	
	public static String STORY_TABLE = "stories";
	public static String STORY_ID = BaseColumns._ID;
	public static String STORY_TITLE = "title";
	public static String STORY_DATE = "date";
	public static String STORY_CONTENT = "content";
	public static String STORY_PERMALINK = "permalink";
	public static String STORY_AUTHORS = "authors";
	public static String STORY_INTELLIGENCE_AUTHORS = "intelligence_authors";
	public static String STORY_INTELLIGENCE_TAGS = "intelligence_tags";
	public static String STORY_INTELLIGENCE_FEED = "intelligence_feed";
	public static String STORY_INTELLIGENCE_TITLE = "intelligence_title";
	public static String STORY_READ = "read";
	public static String STORY_FEED_ID = "feed_id";

}
