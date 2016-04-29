package com.newsblur.network;

public class APIConstants {

    private APIConstants() {} // util class - no instances

    public static final String NEWSBLUR_URL = "https://www.newsblur.com";
    public static final String COOKIE_DOMAIN = ".newsblur.com";
    public static final String URL_AUTOFOLLOW_PREF = NEWSBLUR_URL + "/profile/set_preference";
    
    // TODO: make use of trailing slashes on URLs consistent or document why
    // they are not.

	public static final String URL_LOGIN = NEWSBLUR_URL + "/api/login";
    public static final String URL_LOGINAS = NEWSBLUR_URL + "/reader/login_as";
	public static final String URL_FEEDS = NEWSBLUR_URL + "/reader/feeds/";
	public static final String URL_USER_PROFILE = NEWSBLUR_URL + "/social/profile";
	public static final String URL_MY_PROFILE = NEWSBLUR_URL + "/social/load_user_profile";
	public static final String URL_FOLLOW = NEWSBLUR_URL + "/social/follow";
	public static final String URL_UNFOLLOW = NEWSBLUR_URL + "/social/unfollow";

	public static final String URL_USER_ACTIVITIES = NEWSBLUR_URL + "/social/activities";
	public static final String URL_USER_INTERACTIONS = NEWSBLUR_URL + "/social/interactions";
	public static final String URL_RIVER_STORIES = NEWSBLUR_URL + "/reader/river_stories";
	public static final String URL_SHARED_RIVER_STORIES = NEWSBLUR_URL + "/social/river_stories";
	
	public static final String URL_FEED_STORIES = NEWSBLUR_URL + "/reader/feed";
	public static final String URL_FEED_UNREAD_COUNT = NEWSBLUR_URL + "/reader/feed_unread_count";
	public static final String URL_SOCIALFEED_STORIES = NEWSBLUR_URL + "/social/stories";
	public static final String URL_SIGNUP = NEWSBLUR_URL + "/api/signup";
	public static final String URL_MARK_FEED_AS_READ = NEWSBLUR_URL + "/reader/mark_feed_as_read/";
	public static final String URL_MARK_ALL_AS_READ = NEWSBLUR_URL + "/reader/mark_all_as_read/";
	public static final String URL_MARK_STORIES_READ = NEWSBLUR_URL + "/reader/mark_story_hashes_as_read/";
	public static final String URL_SHARE_STORY = NEWSBLUR_URL + "/social/share_story";
    public static final String URL_MARK_STORY_AS_STARRED = NEWSBLUR_URL + "/reader/mark_story_hash_as_starred/";
    public static final String URL_MARK_STORY_AS_UNSTARRED = NEWSBLUR_URL + "/reader/mark_story_hash_as_unstarred/";
    public static final String URL_MARK_STORY_AS_UNREAD = NEWSBLUR_URL + "/reader/mark_story_as_unread/";
    public static final String URL_MARK_STORY_HASH_UNREAD = NEWSBLUR_URL + "/reader/mark_story_hash_as_unread/";
    public static final String URL_STARRED_STORIES = NEWSBLUR_URL + "/reader/starred_stories";
	public static final String URL_FEED_AUTOCOMPLETE = NEWSBLUR_URL + "/rss_feeds/feed_autocomplete";
	public static final String URL_LIKE_COMMENT = NEWSBLUR_URL + "/social/like_comment";
	public static final String URL_UNLIKE_COMMENT = NEWSBLUR_URL + "/social/remove_like_comment";
	public static final String URL_REPLY_TO = NEWSBLUR_URL + "/social/save_comment_reply";
	public static final String URL_ADD_FEED = NEWSBLUR_URL + "/reader/add_url";
	public static final String URL_DELETE_FEED = NEWSBLUR_URL + "/reader/delete_feed";
	public static final String URL_CLASSIFIER_SAVE = NEWSBLUR_URL + "/classifier/save";
	public static final String URL_STORY_TEXT = NEWSBLUR_URL + "/rss_feeds/original_text";
	public static final String URL_UNREAD_HASHES = NEWSBLUR_URL + "/reader/unread_story_hashes";
    public static final String URL_READ_STORIES = NEWSBLUR_URL + "/reader/read_stories";
    public static final String URL_MOVE_FEED_TO_FOLDERS = NEWSBLUR_URL + "/reader/move_feed_to_folders";
	
	public static final String PARAMETER_FEEDS = "f";
	public static final String PARAMETER_H = "h";
	public static final String PARAMETER_PASSWORD = "password";
	public static final String PARAMETER_USER_ID = "user_id";
    public static final String PARAMETER_USER = "user";
	public static final String PARAMETER_USERNAME = "username";
	public static final String PARAMETER_EMAIL = "email";
	public static final String PARAMETER_USERID = "user_id";
	public static final String PARAMETER_STORYID = "story_id";
	public static final String PARAMETER_STORY_HASH = "story_hash";
	public static final String PARAMETER_FEEDS_STORIES = "feeds_stories";
	public static final String PARAMETER_FEED_SEARCH_TERM = "term";
	public static final String PARAMETER_FOLDER = "folder";
	public static final String PARAMETER_IN_FOLDER = "in_folder";
	public static final String PARAMETER_COMMENT_USERID = "comment_user_id";
	public static final String PARAMETER_FEEDID = "feed_id";
	public static final String PARAMETER_REPLY_TEXT = "reply_comments";
	public static final String PARAMETER_STORY_FEEDID = "story_feed_id";
	public static final String PARAMETER_SHARE_COMMENT = "comments";
	public static final String PARAMETER_SHARE_SOURCEID = "source_user_id";
	public static final String PARAMETER_MARKSOCIAL_JSON = "users_feeds_stories";
	public static final String PARAMETER_URL = "url";
	public static final String PARAMETER_DAYS = "days";
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

    public static final String VALUE_PREFIX_SOCIAL = "social:";
    public static final String VALUE_ALLSOCIAL = "river:blurblogs"; // the magic value passed to the mark-read API for all social feeds
    public static final String VALUE_OLDER = "older";
    public static final String VALUE_NEWER = "newer";
    public static final String VALUE_TRUE = "true";
    public static final String VALUE_STARRED = "starred";
	
    public static final String URL_CONNECT_FACEBOOK = NEWSBLUR_URL + "/oauth/facebook_connect/";
    public static final String URL_CONNECT_TWITTER = NEWSBLUR_URL + "/oauth/twitter_connect/";

	public static final String S3_URL_FEED_ICONS = "https://s3.amazonaws.com/icons.newsblur.com/";
}
