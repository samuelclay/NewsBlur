package com.newsblur.util;

public class PrefConstants {

    private PrefConstants() {} // util class - no instances

	public static final String PREFERENCES = "preferences";
	public static final String PREF_COOKIE = "login_cookie";
	public static final String PREF_UNIQUE_LOGIN = "login_unique";
	
	public final static String USER_USERNAME = "username";
	public final static String USER_WEBSITE = "website";
	public final static String USER_BIO = "bio";
	public final static String USER_FEED_ADDRESS = "feed_address";
	public final static String USER_FEED_TITLE = "feed_link";
	public final static String USER_FOLLOWER_COUNT = "follower_count";
	public final static String USER_LOCATION = "location";
	public final static String USER_ID = "id";
	public final static String USER_PHOTO_SERVICE = "photo_service";
	public final static String USER_PHOTO_URL = "photo_url";
	public final static String USER_POPULAR_PUBLISHERS = "popular_publishers";
	public final static String USER_STORIES_LAST_MONTH = "stories_last_month";
	public final static String USER_AVERAGE_STORIES_PER_MONTH = "average_stories_per_month";
	public final static String USER_FOLLOWING_COUNT = "following_count";
	public final static String USER_SUBSCRIBER_COUNT = "subscribers_count";
	public final static String USER_SHARED_STORIES_COUNT = "shared_stories_count";
	
	public static final String PREFERENCE_TEXT_SIZE = "default_reading_text_size";
	public static final String PREFERENCE_LIST_TEXT_SIZE = "list_text_size";
	
	public static final String PREFERENCE_REGISTRATION_STATE = "registration_stage";
	
    public static final String FEED_STORY_ORDER_PREFIX = "feed_order_";
    public static final String FEED_READ_FILTER_PREFIX = "feed_read_filter_";
    public static final String FOLDER_STORY_ORDER_PREFIX = "folder_order_";
    public static final String FOLDER_READ_FILTER_PREFIX = "folder_read_filter_";
	public static final String ALL_STORIES_FOLDER_NAME = "all_stories";
    public static final String ALL_SHARED_STORIES_FOLDER_NAME = "all_shared_stories";
    public static final String GLOBAL_SHARED_STORIES_FOLDER_NAME = "global_shared_stories";

    public static final String DEFAULT_STORY_ORDER = "default_story_order";
    public static final String DEFAULT_READ_FILTER = "default_read_filter";
    
    public static final String SHOW_PUBLIC_COMMENTS = "show_public_comments";

    public static final String FEED_DEFAULT_FEED_VIEW_PREFIX = "feed_default_feed_view_";
    public static final String FOLDER_DEFAULT_FEED_VIEW_PREFIX = "folder_default_feed_view_";

    public static final String READ_STORIES_FOLDER_NAME = "read_stories";
    public static final String SAVED_STORIES_FOLDER_NAME = "saved_stories";
    public static final String READING_ENTER_IMMERSIVE_SINGLE_TAP = "immersive_enter_single_tap";

    public static final String STORIES_AUTO_OPEN_FIRST = "pref_auto_open_first_unread";
    public static final String STORIES_SHOW_PREVIEWS = "pref_show_content_preview";
    public static final String STORIES_SHOW_THUMBNAILS = "pref_show_thumbnails";

    public static final String ENABLE_OFFLINE = "enable_offline";
    public static final String ENABLE_IMAGE_PREFETCH = "enable_image_prefetch";
    public static final String NETWORK_SELECT = "offline_network_select";
    public static final String KEEP_OLD_STORIES = "keep_old_stories";

    public static final String NETWORK_SELECT_ANY = "ANY";
    public static final String NETWORK_SELECT_NOMO = "NOMO";

    public static final String THEME = "theme";

    public static final String STATE_FILTER = "state_filter";

    public static final String LAST_VACUUM_TIME = "last_vacuum_time";

    public static final String LAST_CLEANUP_TIME = "last_cleanup_time";

    public static final String VOLUME_KEY_NAVIGATION = "volume_key_navigation";
    public static final String MARK_ALL_READ_CONFIRMATION = "pref_confirm_mark_all_read";
}
