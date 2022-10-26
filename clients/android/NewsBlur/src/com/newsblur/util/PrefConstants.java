package com.newsblur.util;

public class PrefConstants {

    private PrefConstants() {} // util class - no instances

	public static final String PREFERENCES = "preferences";
	public static final String PREF_COOKIE = "login_cookie";
	public static final String PREF_UNIQUE_LOGIN = "login_unique";
    public static final String PREF_CUSTOM_SERVER = "custom_server";
	
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

	public static final String IS_PREMIUM = "is_premium";
	public static final String PREMIUM_EXPIRE = "premium_expire";
	
	public static final String PREFERENCE_TEXT_SIZE = "default_reading_text_size";
	public static final String PREFERENCE_LIST_TEXT_SIZE = "list_text_size";
	
	public static final String PREFERENCE_REGISTRATION_STATE = "registration_stage";

    public static final String PREFERENCE_INFREQUENT_CUTOFF = "infrequent cutoff";
	
    public static final String FEED_STORY_ORDER_PREFIX = "feed_order_";
    public static final String FEED_READ_FILTER_PREFIX = "feed_read_filter_";
    public static final String FEED_STORY_LIST_STYLE_PREFIX = "feed_list_style_";
    public static final String FOLDER_STORY_ORDER_PREFIX = "folder_order_";
    public static final String FOLDER_READ_FILTER_PREFIX = "folder_read_filter_";
    public static final String FOLDER_STORY_LIST_STYLE_PREFIX = "folder_list_style_";
	public static final String ALL_STORIES_FOLDER_NAME = "all_stories";
    public static final String ALL_SHARED_STORIES_FOLDER_NAME = "all_shared_stories";
    public static final String GLOBAL_SHARED_STORIES_FOLDER_NAME = "global_shared_stories";
    public static final String INFREQUENT_FOLDER_NAME = "infrequent_stories";

    public static final String DEFAULT_STORY_ORDER = "default_story_order";
    public static final String DEFAULT_READ_FILTER = "default_read_filter";
    
    public static final String SHOW_PUBLIC_COMMENTS = "show_public_comments";

    public static final String FEED_DEFAULT_FEED_VIEW_PREFIX = "feed_default_feed_view_";

    public static final String DEFAULT_BROWSER = "default_browser";

    public static final String READ_STORIES_FOLDER_NAME = "read_stories";
    public static final String SAVED_STORIES_FOLDER_NAME = "saved_stories";

    public static final String STORIES_AUTO_OPEN_FIRST = "pref_auto_open_first_unread";
    public static final String STORIES_MARK_READ_ON_SCROLL = "pref_mark_read_on_scroll";
    public static final String STORIES_SHOW_PREVIEWS_STYLE = "pref_show_content_preview_style";
    public static final String STORIES_THUMBNAIL_STYLE = "pref_thumbnail_style";
    public static final String STORY_MARK_READ_BEHAVIOR = "pref_story_mark_read_behavior";
    public static final String SPACING_STYLE = "pref_spacing_style";

    public static final String ENABLE_OFFLINE = "enable_offline";
    public static final String ENABLE_IMAGE_PREFETCH = "enable_image_prefetch";
    public static final String ENABLE_TEXT_PREFETCH = "enable_text_prefetch";
    public static final String NETWORK_SELECT = "offline_network_select";
    public static final String KEEP_OLD_STORIES = "keep_old_stories";
    public static final String CACHE_AGE_SELECT = "cache_age_select";
    public static final String FEED_LIST_ORDER = "feed_list_order";

    public static final String NETWORK_SELECT_ANY = "ANY";
    public static final String NETWORK_SELECT_NOMO = "NOMO";
    public static final String NETWORK_SELECT_NOMONONME = "NOMONONME";

    public static final String CACHE_AGE_SELECT_2D = "CACHE_AGE_2D";
    public static final String CACHE_AGE_SELECT_7D = "CACHE_AGE_7D";
    public static final String CACHE_AGE_SELECT_14D = "CACHE_AGE_14D";
    public static final String CACHE_AGE_SELECT_30D = "CACHE_AGE_30D";
    public static final long CACHE_AGE_VALUE_2D = 1000L * 60L * 60L * 24L * 2L;
    public static final long CACHE_AGE_VALUE_7D = 1000L * 60L * 60L * 24L * 7L;
    public static final long CACHE_AGE_VALUE_14D = 1000L * 60L * 60L * 24L * 14L;
    public static final long CACHE_AGE_VALUE_30D = 1000L * 60L * 60L * 24L * 30L;

    public static final String ENABLE_ROW_GLOBAL_SHARED = "enable_row_global_shared";
    public static final String ENABLE_ROW_INFREQUENT_STORIES = "enable_row_infrequent_stories";

    public static final String FEED_LIST_ORDER_ALPHABETICAL = "feed_list_order_alphabetical";
    public static final String FEED_LIST_ORDER_MOST_USED_AT_TOP = "feed_list_order_most_used_at_top";

    public static final String THEME = "theme";
    public enum ThemeValue {
        AUTO,
        LIGHT,
        DARK,
        BLACK;
    }

    public static final String STATE_FILTER = "state_filter";

    public static final String LAST_VACUUM_TIME = "last_vacuum_time";

    public static final String LAST_CLEANUP_TIME = "last_cleanup_time";

    public static final String VOLUME_KEY_NAVIGATION = "volume_key_navigation";
    public static final String MARK_ALL_READ_CONFIRMATION = "pref_confirm_mark_all_read";
    public static final String MARK_RANGE_READ_CONFIRMATION = "pref_confirm_mark_range_read";

    public static final String LTR_GESTURE_ACTION = "ltr_gesture_action";
    public static final String RTL_GESTURE_ACTION = "rtl_gesture_action";

    public static final String ENABLE_NOTIFICATIONS = "enable_notifications";

    public static final String READING_FONT = "reading_font";
    public static final String WIDGET_FEED_SET = "widget_feed_set";
    public static final String FEED_CHOOSER_LIST_ORDER = "feed_chooser_list_order";
    public static final String FEED_CHOOSER_FEED_ORDER = "feed_chooser_feed_order";
    public static final String FEED_CHOOSER_FOLDER_VIEW = "feed_chooser_folder_view";
    public static final String WIDGET_BACKGROUND = "widget_background";
    public static final String IN_APP_REVIEW = "in_app_review";
    public static final String LOAD_NEXT_ON_MARK_READ = "load_next_on_mark_read";
}
