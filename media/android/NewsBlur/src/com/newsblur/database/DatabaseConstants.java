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
	public static final String FEED_FAVICON_BORDER = "favicon_border";
	public static final String FEED_ACTIVE = "active";
	public static final String FEED_FAVICON = "favicon";
	public static final String FEED_FAVICON_URL = "favicon_url";
	public static final String FEED_POSITIVE_COUNT = "ps";
	public static final String FEED_NEUTRAL_COUNT = "nt";
	public static final String FEED_NEGATIVE_COUNT = "ng";

	public static final String SOCIALFEED_TABLE = "social_feeds";
	public static final String SOCIAL_FEED_ID = BaseColumns._ID;
	public static final String SOCIAL_FEED_TITLE = "social_feed_title";
	public static final String SOCIAL_FEED_USERNAME = "social_feed_name";
	public static final String SOCIAL_FEED_ICON= "social_feed_icon";
	public static final String SOCIAL_FEED_POSITIVE_COUNT = "ps";
	public static final String SOCIAL_FEED_NEUTRAL_COUNT = "nt";
	public static final String SOCIAL_FEED_NEGATIVE_COUNT = "ng";

	public static final String FEED_FOLDER_MAP_TABLE = "feed_folder_map";
	public static final String FEED_FOLDER_FEED_ID = "feed_feed_id";
	public static final String FEED_FOLDER_FOLDER_NAME = "feed_folder_name";

	public static final String SOCIALFEED_STORY_MAP_TABLE = "socialfeed_story_map";
	public static final String SOCIALFEED_STORY_USER_ID = "socialfeed_story_user_id";
	public static final String SOCIALFEED_STORY_STORYID = "socialfeed_story_storyid";

	public static final String COMMENT_TABLE = "comments";

	public static final String CLASSIFIER_TABLE = "classifiers";
	public static final String CLASSIFIER_ID = BaseColumns._ID;
	public static final String CLASSIFIER_TYPE = "type";
	public static final String CLASSIFIER_KEY = "key";
	public static final String CLASSIFIER_VALUE = "value";

	public static final String UPDATE_TABLE = "offline_updates";
	public static final String UPDATE_ID = BaseColumns._ID;
	public static final String UPDATE_TYPE = "update_type";
	public static final String UPDATE_ARGUMENTS = "update_argument";

	public static final String USER_TABLE = "user_table";
	public static final String USER_USERID = BaseColumns._ID;
	public static final String USER_USERNAME = "username";
	public static final String USER_PHOTO_URL = "photo_url";

	public static final String STORY_TABLE = "stories";
	public static final String STORY_ID = BaseColumns._ID;
	public static final String STORY_AUTHORS = "authors";
	public static final String STORY_TITLE = "title";
	public static final String STORY_DATE = "date";
	public static final String STORY_SHARED_DATE = "sharedDate";
	public static final String STORY_CONTENT = "content";
	public static final String STORY_COMMENT_COUNT = "comment_count";
	public static final String STORY_FEED_ID = "feed_id";
	public static final String STORY_INTELLIGENCE_AUTHORS = "intelligence_authors";
	public static final String STORY_INTELLIGENCE_TAGS = "intelligence_tags";
	public static final String STORY_INTELLIGENCE_FEED = "intelligence_feed";
	public static final String STORY_INTELLIGENCE_TITLE = "intelligence_title";
	public static final String STORY_PERMALINK = "permalink";
	public static final String STORY_READ = "read";
	public static final String STORY_SHARE_COUNT = "share_count";
	public static final String STORY_SHARED_USER_IDS = "shared_user_ids";
	public static final String STORY_FRIEND_USER_IDS = "comment_user_ids";
	public static final String STORY_PUBLIC_USER_IDS = "public_user_ids";
	public static final String STORY_SHORTDATE = "shortDate";
	public static final String STORY_LONGDATE = "longDate";
	public static final String STORY_SOCIAL_USER_ID = "socialUserId";
	public static final String STORY_SOURCE_USER_ID = "sourceUserId";
	public static final String STORY_TAGS = "tags";

	public static final String COMMENT_ID = BaseColumns._ID;
	public static final String COMMENT_STORYID = "comment_storyid";
	public static final String COMMENT_TEXT = "comment_text";
	public static final String COMMENT_DATE = "comment_date";
	public static final String COMMENT_SOURCE_USERID = "comment_source_user";
	public static final String COMMENT_LIKING_USERS = "comment_liking_users";
	public static final String COMMENT_SHAREDDATE = "comment_shareddate";
	public static final String COMMENT_BYFRIEND = "comment_byfriend";
	public static final String COMMENT_USERID = "comment_userid";

	public static final String REPLY_TABLE = "comment_replies";

	public static final String REPLY_ID = BaseColumns._ID;
	public static final String REPLY_COMMENTID = "comment_id"; 
	public static final String REPLY_TEXT = "reply_text";
	public static final String REPLY_USERID = "reply_userid";
	public static final String REPLY_DATE = "reply_date";
	public static final String REPLY_SHORTDATE = "reply_shortdate";

	// Aggregated columns
	public static final String SUM_POS = "sum_postive";
	public static final String SUM_NEUT = "sum_neutral";
	public static final String SUM_NEG = "sum_negative";

	public static final String[] UPDATE_COLUMNS = {
		UPDATE_ID, UPDATE_TYPE, UPDATE_ARGUMENTS
	};

	public static final String[] FEED_COLUMNS = {
		FEED_TABLE + "." + FEED_ACTIVE, FEED_TABLE + "." + FEED_ID, FEED_TABLE + "." + FEED_FAVICON_URL, FEED_TABLE + "." + FEED_TITLE, FEED_TABLE + "." + FEED_LINK, FEED_TABLE + "." + FEED_ADDRESS, FEED_TABLE + "." + FEED_SUBSCRIBERS, FEED_TABLE + "." + FEED_UPDATED_SECONDS, FEED_TABLE + "." + FEED_FAVICON_FADE, FEED_TABLE + "." + FEED_FAVICON_COLOUR, FEED_TABLE + "." + FEED_FAVICON_BORDER,
		FEED_TABLE + "." + FEED_FAVICON, FEED_TABLE + "." + FEED_POSITIVE_COUNT, FEED_TABLE + "." + FEED_NEUTRAL_COUNT, FEED_TABLE + "." + FEED_NEGATIVE_COUNT
	};

	public static final String[] SOCIAL_FEED_COLUMNS = {
		SOCIAL_FEED_ID, SOCIAL_FEED_USERNAME, SOCIAL_FEED_TITLE, SOCIAL_FEED_ICON, SOCIAL_FEED_POSITIVE_COUNT, SOCIAL_FEED_NEUTRAL_COUNT, SOCIAL_FEED_NEGATIVE_COUNT
	};

	public static final String[] COMMENT_COLUMNS = {
		COMMENT_ID, COMMENT_STORYID, COMMENT_TEXT, COMMENT_BYFRIEND, COMMENT_USERID, COMMENT_DATE, COMMENT_LIKING_USERS, COMMENT_SHAREDDATE, COMMENT_SOURCE_USERID
	};

	public static final String[] REPLY_COLUMNS = {
		REPLY_COMMENTID, REPLY_DATE, REPLY_ID, REPLY_SHORTDATE, REPLY_TEXT, REPLY_USERID
	};

	public static final String[] FOLDER_COLUMNS = {
		FOLDER_TABLE + "." + FOLDER_ID, FOLDER_TABLE + "." + FOLDER_NAME, " SUM(" + FEED_POSITIVE_COUNT + ") AS " + SUM_POS, " SUM(" + FEED_NEUTRAL_COUNT + ") AS " + SUM_NEUT, " SUM(" + FEED_NEGATIVE_COUNT + ") AS " + SUM_NEG
	};

	public static final String FOLDER_INTELLIGENCE_ALL = " HAVING SUM(" + DatabaseConstants.FEED_NEGATIVE_COUNT + " + " + DatabaseConstants.FEED_NEUTRAL_COUNT + " + " + DatabaseConstants.FEED_POSITIVE_COUNT + ") >= 0 ";
	public static final String FOLDER_INTELLIGENCE_SOME = " HAVING SUM(" + DatabaseConstants.FEED_NEUTRAL_COUNT + " + " + DatabaseConstants.FEED_POSITIVE_COUNT + ") > 0 ";
	public static final String FOLDER_INTELLIGENCE_BEST = " HAVING SUM(" + DatabaseConstants.FEED_POSITIVE_COUNT + ") > 0 ";

	public static final String SOCIAL_INTELLIGENCE_ALL = "";
	public static final String SOCIAL_INTELLIGENCE_SOME = " (" + DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT + " + " + DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT + ") > 0 ";
	public static final String SOCIAL_INTELLIGENCE_BEST = " (" + DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT + ") > 0 ";
	private static final String SUM_STORY_TOTAL = "storyTotal";


	private static String STORY_SUM_TOTAL = " CASE " + 
	"WHEN MAX(" + DatabaseConstants.STORY_INTELLIGENCE_AUTHORS + "," + DatabaseConstants.STORY_INTELLIGENCE_TAGS + "," + DatabaseConstants.STORY_INTELLIGENCE_TITLE + ") > 0 " + 
	"THEN MAX(" + DatabaseConstants.STORY_INTELLIGENCE_AUTHORS + "," + DatabaseConstants.STORY_INTELLIGENCE_TAGS + "," + DatabaseConstants.STORY_INTELLIGENCE_TITLE + ") " +
	"WHEN MIN(" + DatabaseConstants.STORY_INTELLIGENCE_AUTHORS + "," + DatabaseConstants.STORY_INTELLIGENCE_TAGS + "," + DatabaseConstants.STORY_INTELLIGENCE_TITLE + ") < 0 " + 
	"THEN MIN(" + DatabaseConstants.STORY_INTELLIGENCE_AUTHORS + "," + DatabaseConstants.STORY_INTELLIGENCE_TAGS + "," + DatabaseConstants.STORY_INTELLIGENCE_TITLE + ") " +
	"ELSE " + DatabaseConstants.STORY_INTELLIGENCE_FEED + " " +
	"END AS " + DatabaseConstants.SUM_STORY_TOTAL;

	public static final String STORY_INTELLIGENCE_BEST = DatabaseConstants.SUM_STORY_TOTAL + " > 0 ";
	public static final String STORY_INTELLIGENCE_SOME = DatabaseConstants.SUM_STORY_TOTAL + " >= 0 ";
	public static final String STORY_INTELLIGENCE_ALL = DatabaseConstants.SUM_STORY_TOTAL + " >= 0 ";

	public static final String[] STORY_COLUMNS = {
		STORY_AUTHORS, STORY_COMMENT_COUNT, STORY_CONTENT, STORY_DATE, STORY_SHARED_DATE, STORY_SHORTDATE, STORY_LONGDATE, STORY_TABLE + "." + STORY_FEED_ID, STORY_TABLE + "." + STORY_ID, STORY_INTELLIGENCE_AUTHORS, STORY_INTELLIGENCE_FEED, STORY_INTELLIGENCE_TAGS, STORY_INTELLIGENCE_TITLE,
		STORY_PERMALINK, STORY_READ, STORY_SHARE_COUNT, STORY_TAGS, STORY_TITLE, STORY_SOCIAL_USER_ID, STORY_SOURCE_USER_ID, STORY_SHARED_USER_IDS, STORY_FRIEND_USER_IDS, STORY_PUBLIC_USER_IDS, STORY_SUM_TOTAL
	};



}
