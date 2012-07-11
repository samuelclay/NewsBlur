package com.newsblur.database;

import android.provider.BaseColumns;

public class DatabaseConstants {
	
	public static final String FOLDER_TABLE = "folders";
	public static final String FOLDER_ID = BaseColumns._ID;
	public static final String FOLDER_NAME = "folder_name";
	
	public static final String FEED_TABLE = "feeds";
	public static final String FEED_ID = BaseColumns._ID;
	public static final String FEED_TITLE = "feed_name";
	public static final String FEED_LINK = "link";
	public static final String FEED_ADDRESS = "address";
	public static final String FEED_SUBSCRIBERS = "subscribers";
	public static final String FEED_UPDATED_SECONDS = "updated_seconds";
	public static final String FEED_FAVICON_FADE = "favicon_fade";
	public static final String FEED_FAVICON_COLOUR = "favicon_colour";
	public static final String FEED_ACTIVE = "active";
	public static final String FEED_FAVICON = "favicon";
	public static final String FEED_POSITIVE_COUNT = "ps";
	public static final String FEED_NEUTRAL_COUNT = "nt";
	public static final String FEED_NEGATIVE_COUNT = "ng";
	
	public static final String[] FEED_COLUMNS = {
		FEED_ACTIVE, FEED_ID, FEED_TITLE, FEED_LINK, FEED_ADDRESS, FEED_SUBSCRIBERS, FEED_UPDATED_SECONDS, FEED_FAVICON_FADE, FEED_FAVICON_COLOUR, 
		FEED_FAVICON, FEED_POSITIVE_COUNT, FEED_NEUTRAL_COUNT, FEED_NEGATIVE_COUNT
	};
	
	public static final String FEED_FOLDER_MAP_TABLE = "feed_folder_map";
	public static final String FEED_FOLDER_FEED_ID = "feed_feed_id";
	public static final String FEED_FOLDER_FOLDER_NAME = "feed_folder_name";
	
	public static final String CLASSIFIER_TABLE = "classifiers";
	public static final String CLASSIFIER_ID = BaseColumns._ID;
	public static final String CLASSIFIER_TYPE = "type";
	public static final String CLASSIFIER_KEY = "key";
	public static final String CLASSIFIER_VALUE = "value";
	
	public static final String STORY_TABLE = "stories";
	public static final String STORY_ID = BaseColumns._ID;
	public static final String STORY_TITLE = "title";
	public static final String STORY_DATE = "date";
	public static final String STORY_CONTENT = "content";
	public static final String STORY_PERMALINK = "permalink";
	public static final String STORY_AUTHORS = "authors";
	public static final String STORY_INTELLIGENCE_AUTHORS = "intelligence_authors";
	public static final String STORY_INTELLIGENCE_TAGS = "intelligence_tags";
	public static final String STORY_INTELLIGENCE_FEED = "intelligence_feed";
	public static final String STORY_INTELLIGENCE_TITLE = "intelligence_title";
	public static final String STORY_READ = "read";
	public static final String STORY_FEED_ID = "feed_id";
	
	public static final String[] FOLDER_COLUMNS = {
		FOLDER_TABLE + "." + FOLDER_ID, FOLDER_TABLE + "." + FOLDER_NAME
	};

}
