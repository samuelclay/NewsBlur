package com.newsblur.network;

import android.text.TextUtils;

public class APIConstants {

    private APIConstants() {} // util class - no instances

    private static final String DEFAULT_NEWSBLUR_URL_BASE = "https://newsblur.com";

    private static String CurrentUrlBase = DEFAULT_NEWSBLUR_URL_BASE;

    public static void setCustomServer(String newUrlBase) {
        if (TextUtils.isEmpty(newUrlBase)) return;
        CurrentUrlBase = newUrlBase;
        android.util.Log.i(APIConstants.class.getName(), "setting custom server: " + newUrlBase);
    }

    public static void unsetCustomServer() {
        CurrentUrlBase = DEFAULT_NEWSBLUR_URL_BASE;
    }

    public static boolean isCustomServer() {
        return !DEFAULT_NEWSBLUR_URL_BASE.equals(CurrentUrlBase);
    }

    // TODO: make use of trailing slashes on URLs consistent or document why
    // they are not.

    public static final String PATH_IMAGE_PROXY = "/imageproxy";
	public static final String PATH_LOGIN = "/api/login";
    public static final String PATH_LOGINAS = "/reader/login_as";
	public static final String PATH_FEEDS = "/reader/feeds/";
	public static final String PATH_USER_PROFILE = "/social/profile";
	public static final String PATH_MY_PROFILE = "/social/load_user_profile";
	public static final String PATH_FOLLOW = "/social/follow";
	public static final String PATH_UNFOLLOW = "/social/unfollow";
    public static final String PATH_AUTOFOLLOW_PREF = "/profile/set_preference";
	public static final String PATH_USER_ACTIVITIES = "/social/activities";
	public static final String PATH_USER_INTERACTIONS = "/social/interactions";
	public static final String PATH_RIVER_STORIES = "/reader/river_stories";
	public static final String PATH_SHARED_RIVER_STORIES = "/social/river_stories";
	public static final String PATH_FEED_STORIES = "/reader/feed";
	public static final String PATH_FEED_UNREAD_COUNT = "/reader/feed_unread_count";
	public static final String PATH_SOCIALFEED_STORIES = "/social/stories";
	public static final String PATH_SIGNUP = "/api/signup";
	public static final String PATH_SHARE_EXTERNAL_STORY = "/api/share_story/";
	public static final String PATH_SAVE_EXTERNAL_STORY = "/api/save_story/";
	public static final String PATH_MARK_FEED_AS_READ = "/reader/mark_feed_as_read/";
	public static final String PATH_MARK_ALL_AS_READ = "/reader/mark_all_as_read/";
	public static final String PATH_MARK_STORIES_READ = "/reader/mark_story_hashes_as_read/";
	public static final String PATH_SHARE_STORY = "/social/share_story";
	public static final String PATH_UNSHARE_STORY = "/social/unshare_story";
    public static final String PATH_MARK_STORY_AS_STARRED = "/reader/mark_story_hash_as_starred/";
    public static final String PATH_MARK_STORY_AS_UNSTARRED = "/reader/mark_story_hash_as_unstarred/";
    public static final String PATH_MARK_STORY_AS_UNREAD = "/reader/mark_story_as_unread/";
    public static final String PATH_MARK_STORY_HASH_UNREAD = "/reader/mark_story_hash_as_unread/";
    public static final String PATH_STARRED_STORIES = "/reader/starred_stories";
    public static final String PATH_STARRED_STORY_HASHES = "/reader/starred_story_hashes";
	public static final String PATH_FEED_AUTOCOMPLETE = "/rss_feeds/feed_autocomplete";
	public static final String PATH_LIKE_COMMENT = "/social/like_comment";
	public static final String PATH_UNLIKE_COMMENT = "/social/remove_like_comment";
	public static final String PATH_REPLY_TO = "/social/save_comment_reply";
    public static final String PATH_EDIT_REPLY = "/social/save_comment_reply";
    public static final String PATH_DELETE_REPLY = "/social/remove_comment_reply";
	public static final String PATH_ADD_FEED = "/reader/add_url";
	public static final String PATH_DELETE_FEED = "/reader/delete_feed";
	public static final String PATH_CLASSIFIER_SAVE = "/classifier/save";
	public static final String PATH_STORY_TEXT = "/rss_feeds/original_text";
	public static final String PATH_STORY_CHANGES = "/rss_feeds/story_changes";
	public static final String PATH_UNREAD_HASHES = "/reader/unread_story_hashes";
    public static final String PATH_READ_STORIES = "/reader/read_stories";
    public static final String PATH_MOVE_FEED_TO_FOLDERS = "/reader/move_feed_to_folders";
    public static final String PATH_SAVE_FEED_CHOOSER = "/reader/save_feed_chooser";
    public static final String PATH_CONNECT_FACEBOOK = "/oauth/facebook_connect/";
    public static final String PATH_CONNECT_TWITTER = "/oauth/twitter_connect/";
    public static final String PATH_SET_NOTIFICATIONS = "/notifications/feed/";
    public static final String PATH_INSTA_FETCH = "/rss_feeds/exception_retry";
    public static final String PATH_RENAME_FEED = "/reader/rename_feed";
    public static final String PATH_DELETE_SEARCH = "/reader/delete_search";
    public static final String PATH_SAVE_SEARCH = "/reader/save_search";
    public static final String PATH_ADD_FOLDER = "/reader/add_folder";
    public static final String PATH_DELETE_FOLDER = "/reader/delete_folder";
    public static final String PATH_RENAME_FOLDER = "/reader/rename_folder";
    public static final String PATH_SAVE_RECEIPT = "/profile/save_android_receipt";
    public static final String PATH_FEED_STATISTICS = "/rss_feeds/statistics_embedded/";
    public static final String PATH_FEED_FAVICON_URL = "/rss_feeds/icon/";
    public static final String PATH_EXPORT_OPML = "/import/opml_export";
    public static final String PATH_IMPORT_OPML = "/import/opml_upload";

    public static String buildUrl(String path) {
        return CurrentUrlBase + path;
    }

    public static final String PARAMETER_TITLE = "title";
	public static final String PARAMETER_FEEDS = "f";
	public static final String PARAMETER_H = "h";
	public static final String PARAMETER_PASSWORD = "password";
	public static final String PARAMETER_USER_ID = "user_id";
    public static final String PARAMETER_USER = "user";
	public static final String PARAMETER_USERNAME = "username";
	public static final String PARAMETER_EMAIL = "email";
	public static final String PARAMETER_USERID = "user_id";
	public static final String PARAMETER_STORYID = "story_id";
	public static final String PARAMETER_STORY_URL = "story_url";
	public static final String PARAMETER_STORY_HASH = "story_hash";
	public static final String PARAMETER_FEEDS_STORIES = "feeds_stories";
	public static final String PARAMETER_FEED_SEARCH_TERM = "term";
	public static final String PARAMETER_FOLDER = "folder";
	public static final String PARAMETER_IN_FOLDER = "in_folder";
    public static final String PARAMETER_REPLY_ID = "reply_id";
	public static final String PARAMETER_COMMENT_USERID = "comment_user_id";
	public static final String PARAMETER_FEEDID = "feed_id";
	public static final String PARAMETER_REPLY_TEXT = "reply_comments";
	public static final String PARAMETER_STORY_FEEDID = "story_feed_id";
	public static final String PARAMETER_SHARE_COMMENT = "comments";
	public static final String PARAMETER_SHARE_SOURCEID = "source_user_id";
	public static final String PARAMETER_MARKSOCIAL_JSON = "users_feeds_stories";
	public static final String PARAMETER_URL = "url";
	public static final String PARAMETER_DAYS = "days";
	public static final String PARAMETER_DATA = "data";
	public static final String PARAMETER_UPDATE_COUNTS = "update_counts";
    public static final String PARAMETER_CUTOFF_TIME = "cutoff_timestamp";
	public static final String PARAMETER_DIRECTION = "direction";
	public static final String PARAMETER_PAGE_NUMBER = "page";
	public static final String PARAMETER_ORDER = "order";
	public static final String PARAMETER_READ_FILTER = "read_filter";
	public static final String PARAMETER_INCLUDE_TIMESTAMPS = "include_timestamps";
    public static final String PARAMETER_GLOBAL_FEED = "global_feed";
	public static final String PARAMETER_INCLUDE_HIDDEN = "include_hidden";
	public static final String PARAMETER_LIMIT = "limit";
    public static final String PARAMETER_TO_FOLDER = "to_folders";
    public static final String PARAMETER_IN_FOLDERS = "in_folders";
    public static final String PARAMETER_QUERY = "query";
    public static final String PARAMETER_TAG = "tag";
    public static final String PARAMETER_APPROVED_FEEDS = "approved_feeds";
    public static final String PARAMETER_NOTIFICATION_TYPES = "notification_types";
	public static final String PAREMETER_USER_TAGS = "user_tags";
	public static final String PARAMETER_NOTIFICATION_FILTER = "notification_filter";
    public static final String PARAMETER_RESET_FETCH = "reset_fetch";
    public static final String PARAMETER_INFREQUENT = "infrequent";
    public static final String PARAMETER_FEEDTITLE = "feed_title";
    public static final String PARAMETER_FOLDER_TO_DELETE = "folder_to_delete";
    public static final String PARAMETER_FOLDER_TO_RENAME = "folder_to_rename";
    public static final String PARAMETER_NEW_FOLDER_NAME = "new_folder_name";
    public static final String PARAMETER_ORDER_ID = "order_id";
    public static final String PARAMETER_PRODUCT_ID = "product_id";
    public static final String PARAMETER_SHOW_CHANGES = "show_changes";

    public static final String VALUE_PREFIX_SOCIAL = "social:";
    public static final String VALUE_ALLSOCIAL = "river:blurblogs"; // the magic value passed to the mark-read API for all social feeds
    public static final String VALUE_OLDER = "older";
    public static final String VALUE_NEWER = "newer";
    public static final String VALUE_TRUE = "true";
    public static final String VALUE_FALSE = "false";
    public static final String VALUE_STARRED = "starred";
	
	public static final String S3_URL_FEED_ICONS = "https://s3.amazonaws.com/icons.newsblur.com/";
}
