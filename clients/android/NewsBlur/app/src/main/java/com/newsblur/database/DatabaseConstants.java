package com.newsblur.database;

import java.util.List;

import android.text.TextUtils;
import android.provider.BaseColumns;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import com.newsblur.domain.Feed;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;

public class DatabaseConstants {

    private DatabaseConstants(){} // util class - no instances

    // the largest value that can be queried from an Android DB (config_cursorWindowSize and worst-case encoding overhead)
    public static final int MAX_TEXT_SIZE = 1024 * 2048 / 4;

	private static final String TEXT = " TEXT";
	private static final String INTEGER = " INTEGER";

	public static final String FOLDER_TABLE = "folders";
	public static final String FOLDER_NAME = "folder_name";
	public static final String FOLDER_PARENT_NAMES = "folder_parent_names";
	public static final String FOLDER_CHILDREN_NAMES = "folder_children_names";
	public static final String FOLDER_FEED_IDS = "folder_feedids";

	public static final String FEED_TABLE = "feeds";
	public static final String FEED_ID = BaseColumns._ID;
	public static final String FEED_TITLE = "feed_name";
	public static final String FEED_LINK = "link";
	public static final String FEED_ADDRESS = "address";
	public static final String FEED_SUBSCRIBERS = "subscribers";
	public static final String FEED_OPENS = "opens";
	public static final String FEED_LAST_STORY_DATE = "last_story_date";
	public static final String FEED_AVERAGE_STORIES_PER_MONTH = "average_stories_per_month";
	public static final String FEED_UPDATED_SECONDS = "updated_seconds";
	public static final String FEED_FAVICON_FADE = "favicon_fade";
	public static final String FEED_FAVICON_COLOR = "favicon_color";
	public static final String FEED_FAVICON_BORDER = "favicon_border";
    public static final String FEED_FAVICON_TEXT = "favicon_text_color";
	public static final String FEED_ACTIVE = "active";
	public static final String FEED_FAVICON_URL = "favicon_url";
	public static final String FEED_POSITIVE_COUNT = "ps";
	public static final String FEED_NEUTRAL_COUNT = "nt";
	public static final String FEED_NEGATIVE_COUNT = "ng";
    public static final String FEED_NOTIFICATION_TYPES = "notification_types";
    public static final String FEED_NOTIFICATION_FILTER = "notification_filter";
    public static final String FEED_FETCH_PENDING = "fetch_pending";

	public static final String SOCIALFEED_TABLE = "social_feeds";
	public static final String SOCIAL_FEED_ID = BaseColumns._ID;
	public static final String SOCIAL_FEED_TITLE = "social_feed_title";
	public static final String SOCIAL_FEED_USERNAME = "social_feed_name";
	public static final String SOCIAL_FEED_ICON= "social_feed_icon";
	public static final String SOCIAL_FEED_POSITIVE_COUNT = "ps";
	public static final String SOCIAL_FEED_NEUTRAL_COUNT = "nt";
	public static final String SOCIAL_FEED_NEGATIVE_COUNT = "ng";

	public static final String SOCIALFEED_STORY_MAP_TABLE = "socialfeed_story_map";
	public static final String SOCIALFEED_STORY_USER_ID = "socialfeed_story_user_id";
	public static final String SOCIALFEED_STORY_STORYID = "socialfeed_story_storyid";

	public static final String CLASSIFIER_TABLE = "classifiers";
	public static final String CLASSIFIER_ID = BaseColumns._ID;
	public static final String CLASSIFIER_TYPE = "type";
	public static final String CLASSIFIER_KEY = "key";
	public static final String CLASSIFIER_VALUE = "value";

	public static final String USER_TABLE = "user_table";
	public static final String USER_USERID = BaseColumns._ID;
    public static final String USER_USERNAME = "username";
    public static final String USER_LOCATION = "location";
	public static final String USER_PHOTO_URL = "photo_url";

	public static final String STORY_TABLE = "stories";
	public static final String STORY_ID = BaseColumns._ID;
	public static final String STORY_AUTHORS = "authors";
	public static final String STORY_TITLE = "title";
	public static final String STORY_TIMESTAMP = "timestamp";
	public static final String STORY_SHARED_DATE = "sharedDate";
    public static final String STORY_CONTENT = "content";
    public static final String STORY_SHORT_CONTENT = "short_content";
	public static final String STORY_FEED_ID = "feed_id";
	public static final String STORY_INTELLIGENCE_AUTHORS = "intelligence_authors";
	public static final String STORY_INTELLIGENCE_TAGS = "intelligence_tags";
	public static final String STORY_INTELLIGENCE_FEED = "intelligence_feed";
	public static final String STORY_INTELLIGENCE_TITLE = "intelligence_title";
    public static final String STORY_INTELLIGENCE_TOTAL = "intelligence_total";
	public static final String STORY_PERMALINK = "permalink";
	public static final String STORY_READ = "read";
	public static final String STORY_STARRED = "starred";
	public static final String STORY_STARRED_DATE = "starred_date";
	public static final String STORY_SHARED_USER_IDS = "shared_user_ids";
	public static final String STORY_FRIEND_USER_IDS = "comment_user_ids";
	public static final String STORY_SOCIAL_USER_ID = "socialUserId";
	public static final String STORY_SOURCE_USER_ID = "sourceUserId";
	public static final String STORY_TAGS = "tags";
	public static final String STORY_USER_TAGS = "user_tags";
    public static final String STORY_HASH = "story_hash";
    public static final String STORY_IMAGE_URLS = "image_urls";
    public static final String STORY_LAST_READ_DATE = "last_read_date";
    public static final String STORY_SEARCH_HIT = "search_hit";
    public static final String STORY_THUMBNAIL_URL = "thumbnail_url";
    public static final String STORY_INFREQUENT = "infrequent";
    public static final String STORY_HAS_MODIFICATIONS = "has_modifications";

    public static final String READING_SESSION_TABLE = "reading_session";
    public static final String READING_SESSION_STORY_HASH = "session_story_hash";

    public static final String STORY_TEXT_TABLE = "storytext";
    public static final String STORY_TEXT_STORY_HASH = "story_hash";
    public static final String STORY_TEXT_STORY_TEXT = "story_text";

	public static final String COMMENT_TABLE = "comments";
	public static final String COMMENT_ID = BaseColumns._ID;
	public static final String COMMENT_STORYID = "comment_storyid";
	public static final String COMMENT_TEXT = "comment_text";
	public static final String COMMENT_DATE = "comment_date";
	public static final String COMMENT_SOURCE_USERID = "comment_source_user";
	public static final String COMMENT_LIKING_USERS = "comment_liking_users";
	public static final String COMMENT_SHAREDDATE = "comment_shareddate";
	public static final String COMMENT_BYFRIEND = "comment_byfriend";
	public static final String COMMENT_USERID = "comment_userid";
	public static final String COMMENT_ISPSEUDO = "comment_ispseudo";
	public static final String COMMENT_ISPLACEHOLDER = "comment_isplaceholder";

	public static final String REPLY_TABLE = "comment_replies";
	public static final String REPLY_ID = BaseColumns._ID;
	public static final String REPLY_COMMENTID = "comment_id"; 
	public static final String REPLY_TEXT = "reply_text";
	public static final String REPLY_USERID = "reply_userid";
	public static final String REPLY_DATE = "reply_date";
	public static final String REPLY_SHORTDATE = "reply_shortdate";
	public static final String REPLY_ISPLACEHOLDER = "reply_isplaceholder";

    public static final String ACTION_TABLE = "story_actions";
	public static final String ACTION_ID = BaseColumns._ID;
    public static final String ACTION_TIME = "time";
    public static final String ACTION_TRIED = "tried";
    public static final String ACTION_PARAMS = "action_params";

    public static final String STARREDCOUNTS_TABLE = "starred_counts";
    public static final String STARREDCOUNTS_COUNT = "count";
    public static final String STARREDCOUNTS_TAG = "tag";
    public static final String STARREDCOUNTS_FEEDID = "feed_id";

    public static final String SAVED_SEARCH_TABLE = "saved_search";
    public static final String SAVED_SEARCH_FEED_TITLE = "saved_search_title";
    public static final String SAVED_SEARCH_FAVICON = "saved_search_favicon";
    public static final String SAVED_SEARCH_ADDRESS = "saved_search_address";
    public static final String SAVED_SEARCH_QUERY = "saved_search_query";
    public static final String SAVED_SEARCH_FEED_ID = "saved_search_feed_id";

    public static final String NOTIFY_DISMISS_TABLE = "notify_dimiss";
    public static final String NOTIFY_DISMISS_STORY_HASH = "story_hash";
    public static final String NOTIFY_DISMISS_TIME = "time";

    public static final String FEED_TAGS_TABLE = "feed_tags";
    public static final String FEED_TAGS_FEEDID = "feed_id";
    public static final String FEED_TAGS_TAG = "tag";

    public static final String FEED_AUTHORS_TABLE = "feed_authors";
    public static final String FEED_AUTHORS_FEEDID = "feed_id";
    public static final String FEED_AUTHORS_AUTHOR = "author";

    public static final String SYNC_METADATA_TABLE = "sync_metadata";
    public static final String SYNC_METADATA_KEY = "key";
    public static final String SYNC_METADATA_VALUE = "value";

	static final String FOLDER_SQL = "CREATE TABLE " + FOLDER_TABLE + " (" +
		FOLDER_NAME + TEXT + " PRIMARY KEY, " +  
        FOLDER_PARENT_NAMES + TEXT + ", " +
        FOLDER_CHILDREN_NAMES + TEXT + ", " +
        FOLDER_FEED_IDS + TEXT +
		")";

	static final String FEED_SQL = "CREATE TABLE " + FEED_TABLE + " (" +
		FEED_ID + INTEGER + " PRIMARY KEY, " +
		FEED_ACTIVE + TEXT + ", " +
		FEED_ADDRESS + TEXT + ", " + 
		FEED_FAVICON_COLOR + TEXT + ", " +
		FEED_FAVICON_URL + TEXT + ", " +
		FEED_POSITIVE_COUNT + INTEGER + ", " +
		FEED_NEGATIVE_COUNT + INTEGER + ", " +
		FEED_NEUTRAL_COUNT + INTEGER + ", " +
        FEED_FAVICON_FADE + TEXT + ", " +
        FEED_FAVICON_TEXT + TEXT + ", " +
		FEED_FAVICON_BORDER + TEXT + ", " +
		FEED_LINK + TEXT + ", " + 
		FEED_SUBSCRIBERS + TEXT + ", " +
		FEED_TITLE + TEXT + ", " +
		FEED_OPENS + INTEGER + ", " +
		FEED_AVERAGE_STORIES_PER_MONTH + INTEGER + ", " +
		FEED_LAST_STORY_DATE + TEXT + ", " +
		FEED_UPDATED_SECONDS + INTEGER + ", " +
        FEED_NOTIFICATION_TYPES + TEXT + ", " +
        FEED_NOTIFICATION_FILTER + TEXT + ", " +
        FEED_FETCH_PENDING + TEXT +
		")";
	
	static final String USER_SQL = "CREATE TABLE " + USER_TABLE + " (" + 
		USER_PHOTO_URL + TEXT + ", " + 
		USER_USERID + INTEGER + " PRIMARY KEY, " +
		USER_USERNAME + TEXT + ", " +
        USER_LOCATION + TEXT + 
        ")";
	
	static final String SOCIAL_FEED_SQL = "CREATE TABLE " + SOCIALFEED_TABLE + " (" +
		SOCIAL_FEED_ID + INTEGER + " PRIMARY KEY, " +
		SOCIAL_FEED_POSITIVE_COUNT + INTEGER + ", " +
		SOCIAL_FEED_NEGATIVE_COUNT + INTEGER + ", " +
		SOCIAL_FEED_NEUTRAL_COUNT + INTEGER + ", " +
		SOCIAL_FEED_ICON + TEXT + ", " + 
		SOCIAL_FEED_TITLE + TEXT + ", " + 
		SOCIAL_FEED_USERNAME + TEXT +
		")";

	static final String COMMENT_SQL = "CREATE TABLE " + COMMENT_TABLE + " (" +
		COMMENT_DATE + TEXT + ", " +
		COMMENT_SHAREDDATE + TEXT + ", " +
		COMMENT_SOURCE_USERID + TEXT + ", " +
		COMMENT_ID + TEXT + " PRIMARY KEY, " +
		COMMENT_LIKING_USERS + TEXT + ", " +
		COMMENT_BYFRIEND + TEXT + ", " +
		COMMENT_STORYID + TEXT + ", " + 
		COMMENT_TEXT + TEXT + ", " +
		COMMENT_USERID + TEXT + ", " +
        COMMENT_ISPSEUDO + TEXT + ", " +
        COMMENT_ISPLACEHOLDER + TEXT +
		")";
	
	static final String REPLY_SQL = "CREATE TABLE " + REPLY_TABLE + " (" +
		REPLY_DATE + TEXT + ", " +
		REPLY_SHORTDATE + TEXT + ", " +
		REPLY_ID + TEXT + " PRIMARY KEY, " +
		REPLY_COMMENTID + TEXT + ", " + 
		REPLY_TEXT + TEXT + ", " +
		REPLY_USERID + TEXT + ", " +
        REPLY_ISPLACEHOLDER + TEXT +
		")";
	
	static final String STORY_SQL = "CREATE TABLE " + STORY_TABLE + " (" + 
		STORY_HASH + TEXT + " PRIMARY KEY, " +
		STORY_AUTHORS + TEXT + ", " +
		STORY_CONTENT + TEXT + ", " +
		STORY_SHORT_CONTENT + TEXT + ", " +
		STORY_TIMESTAMP + INTEGER + ", " +
		STORY_SHARED_DATE + INTEGER + ", " +
		STORY_FEED_ID + INTEGER + ", " +
		STORY_ID + TEXT + ", " +
		STORY_INTELLIGENCE_AUTHORS + INTEGER + ", " +
		STORY_INTELLIGENCE_FEED + INTEGER + ", " +
		STORY_INTELLIGENCE_TAGS + INTEGER + ", " +
		STORY_INTELLIGENCE_TITLE + INTEGER + ", " +
		STORY_INTELLIGENCE_TOTAL + INTEGER + ", " +
		STORY_SOCIAL_USER_ID + TEXT + ", " +
		STORY_SOURCE_USER_ID + TEXT + ", " +
		STORY_SHARED_USER_IDS + TEXT + ", " +
		STORY_FRIEND_USER_IDS + TEXT + ", " +
		STORY_TAGS + TEXT + ", " +
		STORY_USER_TAGS + TEXT + ", " +
		STORY_PERMALINK + TEXT + ", " + 
		STORY_READ + INTEGER + ", " +
		STORY_STARRED + INTEGER + ", " +
		STORY_STARRED_DATE + INTEGER + ", " +
        STORY_INFREQUENT + INTEGER + ", " +
		STORY_TITLE + TEXT + ", " +
        STORY_IMAGE_URLS + TEXT + ", " +
        STORY_LAST_READ_DATE + INTEGER + ", " +
        STORY_SEARCH_HIT + TEXT + ", " +
        STORY_THUMBNAIL_URL + TEXT + ", " +
        STORY_HAS_MODIFICATIONS + INTEGER +
        ")";

    static final String READING_SESSION_SQL = "CREATE TABLE " + READING_SESSION_TABLE + " (" +
        READING_SESSION_STORY_HASH + TEXT +
        ")";

    static final String STORY_TEXT_SQL = "CREATE TABLE " + STORY_TEXT_TABLE + " (" +
        STORY_TEXT_STORY_HASH + TEXT + ", " +
        STORY_TEXT_STORY_TEXT + TEXT +
        ")";

	static final String CLASSIFIER_SQL = "CREATE TABLE " + CLASSIFIER_TABLE + " (" +
		CLASSIFIER_ID + TEXT + ", " +
		CLASSIFIER_KEY + TEXT + ", " + 
		CLASSIFIER_TYPE + TEXT + ", " +
		CLASSIFIER_VALUE + TEXT +
		")";

	static final String SOCIALFEED_STORIES_SQL = "CREATE TABLE " + SOCIALFEED_STORY_MAP_TABLE + " (" +
		SOCIALFEED_STORY_STORYID  + TEXT + " NOT NULL, " +
		SOCIALFEED_STORY_USER_ID  + INTEGER + " NOT NULL, " +
		"PRIMARY KEY (" + SOCIALFEED_STORY_STORYID  + ", " + SOCIALFEED_STORY_USER_ID + ") " + 
	    ")";

    static final String ACTION_SQL = "CREATE TABLE " + ACTION_TABLE + " (" +
        ACTION_ID + INTEGER + " PRIMARY KEY AUTOINCREMENT, " +
        ACTION_TIME + INTEGER + " NOT NULL, " +
        ACTION_TRIED + INTEGER + ", " +
        ACTION_PARAMS + TEXT +
        ")";

	static final String STARREDCOUNTS_SQL = "CREATE TABLE " + STARREDCOUNTS_TABLE + " (" +
        STARREDCOUNTS_COUNT + INTEGER + " NOT NULL, " +
	    STARREDCOUNTS_TAG + TEXT + ", " +
	    STARREDCOUNTS_FEEDID + TEXT +
        ")";

	static final String SAVED_SEARCH_SQL = "CREATE TABLE " + SAVED_SEARCH_TABLE + " (" +
			SAVED_SEARCH_FEED_TITLE + TEXT + ", " +
			SAVED_SEARCH_FAVICON + TEXT + ", " +
			SAVED_SEARCH_ADDRESS + TEXT + ", " +
			SAVED_SEARCH_QUERY + TEXT + ", " +
			SAVED_SEARCH_FEED_ID +
			")";

    static final String NOTIFY_DISMISS_SQL = "CREATE TABLE " + NOTIFY_DISMISS_TABLE + " (" +
        NOTIFY_DISMISS_STORY_HASH + TEXT + ", " +
        NOTIFY_DISMISS_TIME + INTEGER + " NOT NULL " +
        ")";

    static final String FEED_TAGS_SQL = "CREATE TABLE " + FEED_TAGS_TABLE + " (" +
        FEED_TAGS_FEEDID + TEXT + ", " +
        FEED_TAGS_TAG + TEXT +
        ")";

    static final String FEED_AUTHORS_SQL = "CREATE TABLE " + FEED_AUTHORS_TABLE + " (" +
        FEED_AUTHORS_FEEDID + TEXT + ", " +
        FEED_AUTHORS_AUTHOR + TEXT +
        ")";

    static final String SYNC_METADATA_SQL = "CREATE TABLE " + SYNC_METADATA_TABLE + " (" +
        SYNC_METADATA_KEY + TEXT + " PRIMARY KEY, " +
        SYNC_METADATA_VALUE + TEXT +
        ")";

	private static final String[] BASE_STORY_COLUMNS = {
		STORY_AUTHORS, STORY_SHORT_CONTENT, STORY_TIMESTAMP, STORY_SHARED_DATE,
        STORY_TABLE + "." + STORY_FEED_ID, STORY_TABLE + "." + STORY_ID,
        STORY_INTELLIGENCE_AUTHORS, STORY_INTELLIGENCE_FEED, STORY_INTELLIGENCE_TAGS, STORY_INTELLIGENCE_TOTAL,
        STORY_INTELLIGENCE_TITLE, STORY_PERMALINK, STORY_READ, STORY_STARRED, STORY_STARRED_DATE, STORY_TAGS, STORY_USER_TAGS, STORY_TITLE,
        STORY_SOCIAL_USER_ID, STORY_SOURCE_USER_ID, STORY_SHARED_USER_IDS, STORY_FRIEND_USER_IDS, STORY_HASH,
        STORY_LAST_READ_DATE, STORY_THUMBNAIL_URL, STORY_HAS_MODIFICATIONS,
	};

    private static final String STORY_COLUMNS = 
        TextUtils.join(",", BASE_STORY_COLUMNS) + ", " + 
        FEED_TITLE + ", " + FEED_FAVICON_URL + ", " + FEED_FAVICON_COLOR + ", " + FEED_FAVICON_BORDER + ", " + FEED_FAVICON_FADE + ", " + FEED_FAVICON_TEXT;

	public static final String STORY_QUERY_BASE_0 =
			"SELECT " +
					STORY_COLUMNS +
					" FROM " + STORY_TABLE +
					" INNER JOIN " + FEED_TABLE +
					" ON " + STORY_TABLE + "." + STORY_FEED_ID + " = " + FEED_TABLE + "." + FEED_ID +
					" WHERE ";
	public static final String STORY_QUERY_BASE_1 =
        "SELECT " +
        STORY_COLUMNS +
        " FROM " + STORY_TABLE +
        " INNER JOIN " + FEED_TABLE + 
        " ON " + STORY_TABLE + "." + STORY_FEED_ID + " = " + FEED_TABLE + "." + FEED_ID +
        " WHERE ";
    public static final String STORY_QUERY_BASE_2 =
        " GROUP BY " + STORY_HASH;

    public static final String SESSION_STORY_QUERY_BASE = 
        STORY_QUERY_BASE_1 +
        STORY_HASH + " IN (" +
        " SELECT DISTINCT " + READING_SESSION_STORY_HASH +
        " FROM " + READING_SESSION_TABLE +
        ")" + 
        STORY_QUERY_BASE_2;

    public static String NOTIFY_FOCUS_STORY_QUERY = 
        STORY_QUERY_BASE_1 +
        STORY_FEED_ID + " IN (SELECT " + FEED_ID + " FROM " + FEED_TABLE + " WHERE " + FEED_NOTIFICATION_FILTER + " = '" + Feed.NOTIFY_FILTER_FOCUS + "')" +
        " AND " + STORY_INTELLIGENCE_TOTAL + " > 0 " +
        STORY_QUERY_BASE_2 +
        " ORDER BY " + STORY_TIMESTAMP + " DESC";

    public static String NOTIFY_UNREAD_STORY_QUERY = 
        STORY_QUERY_BASE_1 +
        STORY_FEED_ID + " IN (SELECT " + FEED_ID + " FROM " + FEED_TABLE + " WHERE " + FEED_NOTIFICATION_FILTER + " = '" + Feed.NOTIFY_FILTER_UNREAD + "')" +
        " AND " + STORY_INTELLIGENCE_TOTAL + " >= 0 " +
        STORY_QUERY_BASE_2 +
        " ORDER BY " + STORY_TIMESTAMP + " DESC";

    public static final String JOIN_STORIES_ON_SOCIALFEED_MAP = 
        " INNER JOIN " + STORY_TABLE + " ON " + STORY_TABLE + "." + STORY_ID + " = " + SOCIALFEED_STORY_MAP_TABLE + "." + SOCIALFEED_STORY_STORYID;

    public static final String READ_STORY_ORDER = STORY_LAST_READ_DATE + " DESC";

    public static final String SHARED_STORY_ORDER = STORY_SHARED_DATE + " DESC";

    /**
     * Appends to the given story query any and all selection statements that are required to satisfy the specified
     * filtration parameters.
     */ 
    public static void appendStorySelection(StringBuilder q, List<String> selArgs, ReadFilter readFilter, StateFilter stateFilter, String requireQueryHit) {
        if (readFilter == ReadFilter.UNREAD) {
            q.append(" AND (").append(STORY_READ).append(" = 0)");
        }

        String stateSelection =  getStorySelectionFromState(stateFilter);
        if (stateSelection != null) {
            q.append(" AND ").append(stateSelection);
        }

        if (requireQueryHit != null) {
            q.append(" AND (").append(STORY_TABLE).append(".").append(STORY_SEARCH_HIT).append(" = ?)");
            selArgs.add(requireQueryHit);
        }
    }

    /**
     * Selection args to filter stories.
     */
    public static String getStorySelectionFromState(StateFilter state) {
        switch (state) {
        case ALL:
            return null;
        case SOME:
            return STORY_INTELLIGENCE_TOTAL + " >= 0 ";
        case NEUT:
            return STORY_INTELLIGENCE_TOTAL + " = 0 ";
        case BEST:
            return STORY_INTELLIGENCE_TOTAL + " > 0 ";
        case NEG:
            return STORY_INTELLIGENCE_TOTAL + " < 0 ";
        case SAVED:
            return STORY_STARRED + " = 1";
        default:
            return null;
        }
    }
    
    public static String getStorySortOrder(StoryOrder storyOrder) {
        // it is not uncommon for a feed to have multiple stories with exactly the same timestamp. we
        // arbitrarily pick a second sort column so sortation is stable.
        if (storyOrder == StoryOrder.NEWEST) {
            return STORY_TIMESTAMP + " DESC, " + STORY_HASH + " DESC";
        } else {
            return STORY_TIMESTAMP + " ASC, " + STORY_HASH + " ASC";
        }
    }

    public static String getSavedStoriesSortOrder(StoryOrder storyOrder) {
        // "newest" in this context means "most recently saved"
        if (storyOrder == StoryOrder.NEWEST) {
            return STORY_STARRED_DATE + " DESC";
        } else {
            return STORY_STARRED_DATE + " ASC";
        }
    }
    
    public static Long nullIfZero(Long l) {
        if (l == null) return null;
        if (l.longValue() == 0L) return null;
        return l;
    }

    public static final Gson JsonHelper = new Gson();

    /**
     * A quick way to represent a list of strings as a single DB value. Though not particularly
     * efficient, this avoids having to add more DB tables to have one-to-many or many-to-many
     * relationships, since SQLite gets less stable as DB complexity increases.
     */
    public static String flattenStringList(List<String> list) {
        return JsonHelper.toJson(list);
    }

    public static List<String> unflattenStringList(String flat) {
        return JsonHelper.fromJson(flat, new TypeToken<List<String>>(){}.getType());
    }

    public static final String SYNC_METADATA_KEY_SESSION_FEED_SET = "session_feed_set";
}
