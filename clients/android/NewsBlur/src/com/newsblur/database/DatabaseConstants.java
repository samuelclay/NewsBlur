package com.newsblur.database;

import android.database.Cursor;
import android.text.TextUtils;
import android.provider.BaseColumns;

import com.newsblur.util.AppConstants;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StateFilter;
import com.newsblur.util.StoryOrder;

public class DatabaseConstants {

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

    public static final String STARRED_STORY_COUNT_TABLE = "starred_story_count";
    public static final String STARRED_STORY_COUNT_COUNT = "count";

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
	public static final String STORY_COMMENT_COUNT = "comment_count";
	public static final String STORY_FEED_ID = "feed_id";
	public static final String STORY_INTELLIGENCE_AUTHORS = "intelligence_authors";
	public static final String STORY_INTELLIGENCE_TAGS = "intelligence_tags";
	public static final String STORY_INTELLIGENCE_FEED = "intelligence_feed";
	public static final String STORY_INTELLIGENCE_TITLE = "intelligence_title";
	public static final String STORY_PERMALINK = "permalink";
	public static final String STORY_READ = "read";
	public static final String STORY_READ_THIS_SESSION = "read_this_session";
	public static final String STORY_STARRED = "starred";
	public static final String STORY_STARRED_DATE = "starred_date";
	public static final String STORY_SHARE_COUNT = "share_count";
	public static final String STORY_SHARED_USER_IDS = "shared_user_ids";
	public static final String STORY_FRIEND_USER_IDS = "comment_user_ids";
	public static final String STORY_PUBLIC_USER_IDS = "public_user_ids";
	public static final String STORY_SHORTDATE = "shortDate";
	public static final String STORY_LONGDATE = "longDate";
	public static final String STORY_SOCIAL_USER_ID = "socialUserId";
	public static final String STORY_SOURCE_USER_ID = "sourceUserId";
	public static final String STORY_TAGS = "tags";
    public static final String STORY_HASH = "story_hash";
    public static final String STORY_ACTIVE = "active";
    public static final String STORY_IMAGE_URLS = "image_urls";
    public static final String STORY_LAST_READ_DATE = "last_read_date";

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

	public static final String REPLY_TABLE = "comment_replies";
	public static final String REPLY_ID = BaseColumns._ID;
	public static final String REPLY_COMMENTID = "comment_id"; 
	public static final String REPLY_TEXT = "reply_text";
	public static final String REPLY_USERID = "reply_userid";
	public static final String REPLY_DATE = "reply_date";
	public static final String REPLY_SHORTDATE = "reply_shortdate";

    public static final String ACTION_TABLE = "story_actions";
	public static final String ACTION_ID = BaseColumns._ID;
    public static final String ACTION_TIME = "time";
    public static final String ACTION_MARK_READ = "mark_read";
    public static final String ACTION_MARK_UNREAD = "mark_unread";
    public static final String ACTION_SAVE = "save";
    public static final String ACTION_UNSAVE = "unsave";
    public static final String ACTION_SHARE = "share";
    public static final String ACTION_UNSHARE = "unshare";
    public static final String ACTION_LIKE_COMMENT = "like_comment";
    public static final String ACTION_UNLIKE_COMMENT = "unlike_comment";
    public static final String ACTION_REPLY = "reply";
    public static final String ACTION_COMMENT_TEXT = "comment_text";
    public static final String ACTION_STORY_HASH = "story_hash";
    public static final String ACTION_FEED_ID = "feed_id";
    public static final String ACTION_INCLUDE_OLDER = "include_older";
    public static final String ACTION_INCLUDE_NEWER = "include_newer";
    public static final String ACTION_STORY_ID = "story_id";
    public static final String ACTION_SOURCE_USER_ID = "source_user_id";
    public static final String ACTION_COMMENT_ID = "comment_id";

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
		FEED_UPDATED_SECONDS +
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
        COMMENT_ISPSEUDO + TEXT +
		")";
	
	static final String REPLY_SQL = "CREATE TABLE " + REPLY_TABLE + " (" +
		REPLY_DATE + TEXT + ", " +
		REPLY_SHORTDATE + TEXT + ", " +
		REPLY_ID + TEXT + " PRIMARY KEY, " +
		REPLY_COMMENTID + TEXT + ", " + 
		REPLY_TEXT + TEXT + ", " +
		REPLY_USERID + TEXT +
		")";
	
	static final String STORY_SQL = "CREATE TABLE " + STORY_TABLE + " (" + 
		STORY_HASH + TEXT + ", " +
		STORY_AUTHORS + TEXT + ", " +
		STORY_CONTENT + TEXT + ", " +
		STORY_SHORT_CONTENT + TEXT + ", " +
		STORY_TIMESTAMP + INTEGER + ", " +
		STORY_SHARED_DATE + INTEGER + ", " +
		STORY_SHORTDATE + TEXT + ", " +
		STORY_LONGDATE + TEXT + ", " +
		STORY_FEED_ID + INTEGER + ", " +
		STORY_ID + TEXT + " PRIMARY KEY, " +
		STORY_INTELLIGENCE_AUTHORS + INTEGER + ", " +
		STORY_INTELLIGENCE_FEED + INTEGER + ", " +
		STORY_INTELLIGENCE_TAGS + INTEGER + ", " +
		STORY_INTELLIGENCE_TITLE + INTEGER + ", " +
		STORY_COMMENT_COUNT + INTEGER + ", " +
		STORY_SHARE_COUNT + INTEGER + ", " +
		STORY_SOCIAL_USER_ID + TEXT + ", " +
		STORY_SOURCE_USER_ID + TEXT + ", " +
		STORY_SHARED_USER_IDS + TEXT + ", " +
		STORY_PUBLIC_USER_IDS + TEXT + ", " +
		STORY_FRIEND_USER_IDS + TEXT + ", " +
		STORY_TAGS + TEXT + ", " +
		STORY_PERMALINK + TEXT + ", " + 
		STORY_READ + INTEGER + ", " +
		STORY_READ_THIS_SESSION + INTEGER + ", " +
		STORY_STARRED + INTEGER + ", " +
		STORY_STARRED_DATE + INTEGER + ", " +
		STORY_TITLE + TEXT + ", " +
        STORY_ACTIVE + INTEGER + " DEFAULT 0, " +
        STORY_IMAGE_URLS + TEXT + ", " +
        STORY_LAST_READ_DATE + INTEGER +
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

    static final String STARRED_STORIES_COUNT_SQL = "CREATE TABLE " + STARRED_STORY_COUNT_TABLE + " (" +
        STARRED_STORY_COUNT_COUNT + INTEGER + " NOT NULL" +
        ")";

    static final String ACTION_SQL = "CREATE TABLE " + ACTION_TABLE + " (" +
        ACTION_ID + INTEGER + " PRIMARY KEY AUTOINCREMENT, " +
        ACTION_TIME + INTEGER + " NOT NULL, " +
        ACTION_MARK_READ + INTEGER + " DEFAULT 0, " +
        ACTION_MARK_UNREAD + INTEGER + " DEFAULT 0, " +
        ACTION_SAVE + INTEGER + " DEFAULT 0, " +
        ACTION_UNSAVE + INTEGER + " DEFAULT 0, " +
        ACTION_SHARE + INTEGER + " DEFAULT 0, " +
        ACTION_UNSHARE + INTEGER + " DEFAULT 0, " +
        ACTION_LIKE_COMMENT + INTEGER + " DEFAULT 0, " +
        ACTION_UNLIKE_COMMENT + INTEGER + " DEFAULT 0, " +
        ACTION_REPLY + INTEGER + " DEFAULT 0, " +
        ACTION_COMMENT_TEXT + TEXT + ", " +
        ACTION_STORY_HASH + TEXT + ", " +
        ACTION_FEED_ID + TEXT + ", " +
        ACTION_INCLUDE_OLDER + INTEGER + ", " +
        ACTION_INCLUDE_NEWER + INTEGER + ", " +
        ACTION_STORY_ID + TEXT + ", " +
        ACTION_SOURCE_USER_ID + TEXT + ", " +
        ACTION_COMMENT_ID + TEXT +
        ")";

	public static final String[] FEED_COLUMNS = {
		FEED_TABLE + "." + FEED_ACTIVE, FEED_TABLE + "." + FEED_ID, FEED_TABLE + "." + FEED_FAVICON_URL, FEED_TABLE + "." + FEED_TITLE, FEED_TABLE + "." + FEED_LINK, FEED_TABLE + "." + FEED_ADDRESS, FEED_TABLE + "." + FEED_SUBSCRIBERS, FEED_TABLE + "." + FEED_UPDATED_SECONDS, FEED_TABLE + "." + FEED_FAVICON_FADE, FEED_TABLE + "." + FEED_FAVICON_COLOR, FEED_TABLE + "." + FEED_FAVICON_BORDER, FEED_TABLE + "." + FEED_FAVICON_TEXT,
		FEED_TABLE + "." + FEED_POSITIVE_COUNT, FEED_TABLE + "." + FEED_NEUTRAL_COUNT, FEED_TABLE + "." + FEED_NEGATIVE_COUNT
	};

	public static final String[] SOCIAL_FEED_COLUMNS = {
		SOCIAL_FEED_ID, SOCIAL_FEED_USERNAME, SOCIAL_FEED_TITLE, SOCIAL_FEED_ICON, SOCIAL_FEED_POSITIVE_COUNT, SOCIAL_FEED_NEUTRAL_COUNT, SOCIAL_FEED_NEGATIVE_COUNT
	};

    public static final String SUM_STORY_TOTAL = "storyTotal";
	private static String STORY_SUM_TOTAL = " CASE " + 
	"WHEN MAX(" + STORY_INTELLIGENCE_AUTHORS + "," + STORY_INTELLIGENCE_TAGS + "," + STORY_INTELLIGENCE_TITLE + ") > 0 " + 
	"THEN MAX(" + STORY_INTELLIGENCE_AUTHORS + "," + STORY_INTELLIGENCE_TAGS + "," + STORY_INTELLIGENCE_TITLE + ") " +
	"WHEN MIN(" + STORY_INTELLIGENCE_AUTHORS + "," + STORY_INTELLIGENCE_TAGS + "," + STORY_INTELLIGENCE_TITLE + ") < 0 " + 
	"THEN MIN(" + STORY_INTELLIGENCE_AUTHORS + "," + STORY_INTELLIGENCE_TAGS + "," + STORY_INTELLIGENCE_TITLE + ") " +
	"ELSE " + STORY_INTELLIGENCE_FEED + " " +
	"END AS " + SUM_STORY_TOTAL;
	private static final String STORY_INTELLIGENCE_BEST = SUM_STORY_TOTAL + " > 0 ";
	private static final String STORY_INTELLIGENCE_SOME = SUM_STORY_TOTAL + " >= 0 ";
	private static final String STORY_INTELLIGENCE_NEUT = SUM_STORY_TOTAL + " = 0 ";
	private static final String STORY_INTELLIGENCE_NEG = SUM_STORY_TOTAL + " < 0 ";

	public static final String[] STORY_COLUMNS = {
		STORY_AUTHORS, STORY_COMMENT_COUNT, STORY_SHORT_CONTENT, STORY_TIMESTAMP, STORY_SHARED_DATE, STORY_SHORTDATE, STORY_LONGDATE,
        STORY_TABLE + "." + STORY_FEED_ID, STORY_TABLE + "." + STORY_ID, STORY_INTELLIGENCE_AUTHORS, STORY_INTELLIGENCE_FEED, STORY_INTELLIGENCE_TAGS,
        STORY_INTELLIGENCE_TITLE, STORY_PERMALINK, STORY_READ, STORY_STARRED, STORY_STARRED_DATE, STORY_SHARE_COUNT, STORY_TAGS, STORY_TITLE,
        STORY_SOCIAL_USER_ID, STORY_SOURCE_USER_ID, STORY_SHARED_USER_IDS, STORY_FRIEND_USER_IDS, STORY_PUBLIC_USER_IDS, STORY_SUM_TOTAL, STORY_HASH,
        STORY_LAST_READ_DATE
	};

    public static final String MULTIFEED_STORIES_QUERY_BASE = 
        "SELECT " + TextUtils.join(",", STORY_COLUMNS) + ", " + 
        FEED_TITLE + ", " + FEED_FAVICON_URL + ", " + FEED_FAVICON_COLOR + ", " + FEED_FAVICON_BORDER + ", " + FEED_FAVICON_FADE + ", " + FEED_FAVICON_TEXT;

    public static final String JOIN_FEEDS_ON_STORIES =
        " INNER JOIN " + FEED_TABLE + " ON " + STORY_TABLE + "." + STORY_FEED_ID + " = " + FEED_TABLE + "." + FEED_ID;

    public static final String JOIN_STORIES_ON_SOCIALFEED_MAP = 
        " INNER JOIN " + STORY_TABLE + " ON " + STORY_TABLE + "." + STORY_ID + " = " + SOCIALFEED_STORY_MAP_TABLE + "." + SOCIALFEED_STORY_STORYID;

    public static final String JOIN_SOCIAL_FEEDS_ON_SOCIALFEED_MAP =
        " INNER JOIN " + SOCIALFEED_TABLE + " ON " + SOCIALFEED_TABLE + "." + SOCIAL_FEED_ID + " = " + SOCIALFEED_STORY_MAP_TABLE + "." + SOCIALFEED_STORY_USER_ID;

    public static final String STARRED_STORY_ORDER = STORY_STARRED_DATE + " DESC";
    public static final String READ_STORY_ORDER = STORY_LAST_READ_DATE + " DESC";

    /**
     * Appends to the given story query any and all selection statements that are required to satisfy the specified
     * filtration parameters, dedup column, and ordering requirements.
     */ 
    public static void appendStorySelectionGroupOrder(StringBuilder q, ReadFilter readFilter, StoryOrder order, StateFilter stateFilter, String dedupCol) {
        if (readFilter == ReadFilter.UNREAD) {
            // When a user is viewing "unread only" stories, what they really want are stories that were unread when they started reading,
            // or else the selection set will constantly change as they see things!
            q.append(" AND ((" + STORY_READ + " = 0) OR (" + STORY_READ_THIS_SESSION + " = 1))");
        } else if (readFilter == ReadFilter.PURE_UNREAD) {
            // This means really just unreads, useful for getting counts
            q.append(" AND (" + STORY_READ + " = 0)");
        }

        String stateSelection =  getStorySelectionFromState(stateFilter);
        if (stateSelection != null) {
            q.append(" AND " + stateSelection);
        }
        
        q.append(" AND (" + STORY_TABLE + "." + STORY_ACTIVE + " = 1)");

        if (dedupCol != null) {
            q.append( " GROUP BY " + dedupCol);
        }

        if (order != null) {
            q.append(" ORDER BY " + getStorySortOrder(order));
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
            return STORY_INTELLIGENCE_SOME;
        case NEUT:
            return STORY_INTELLIGENCE_NEUT;
        case BEST:
            return STORY_INTELLIGENCE_BEST;
        case NEG:
            return STORY_INTELLIGENCE_NEG;
        default:
            return null;
        }
    }
    
    /**
     * Selection args to filter feeds.
     */
    public static String getFeedSelectionFromState(StateFilter state) {
        switch (state) {
        case ALL:
            return null;
        case SOME:
            return "((" + FEED_NEUTRAL_COUNT + " + " + FEED_POSITIVE_COUNT + ") > 0)";
        case BEST:
            return "(" + FEED_POSITIVE_COUNT + " > 0)";
        default:
            return null;
        }
    }

    /**
     * Selection args to filter social feeds.
     */
    public static String getBlogSelectionFromState(StateFilter state) {
        switch (state) {
        case ALL:
            return null;
        case SOME:
            return "((" + SOCIAL_FEED_NEUTRAL_COUNT + " + " + SOCIAL_FEED_POSITIVE_COUNT + ") > 0)";
        case BEST:
            return "(" + SOCIAL_FEED_POSITIVE_COUNT + " > 0)";
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
    
    public static Long nullIfZero(Long l) {
        if (l == null) return null;
        if (l.longValue() == 0L) return null;
        return l;
    }

    public static String getStr(Cursor c, String colName) {
        return c.getString(c.getColumnIndex(colName));
    }

}
