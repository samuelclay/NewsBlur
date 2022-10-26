package com.newsblur.util;

public class AppConstants {

    private AppConstants() {} // util class - no instances

    // Enables high-volume logging that may be useful for debugging. This should
    // never be enabled for releases, as it not only slows down the app considerably,
    // it will log sensitive info such as passwords!
    public static final boolean VERBOSE_LOG = false;
    public static final boolean VERBOSE_LOG_DB = false;
    public static final boolean VERBOSE_LOG_NET = false;
	
	public static final String FOLDER_PRE = "folder_collapsed";
	
    // the name to give the "root" folder in the local DB since the API does not assign it one.
    // this name should be unique and such that it will sort to the beginning of a list, ideally.
    public static final String ROOT_FOLDER = "0000_TOP_LEVEL_";

    public static final String LAST_APP_VERSION = "LAST_APP_VERSION";

    // a pref for the time we completed the last full sync of the feed/fodler list
    public static final String LAST_SYNC_TIME = "LAST_SYNC_TIME";

    // how long to wait before auto-syncing the feed/folder list
    public static final long AUTO_SYNC_TIME_MILLIS = 15L * 60L * 1000L;

    // how often to rebuild the DB
    public static final long VACUUM_TIME_MILLIS = 12L * 60L * 60L * 1000L;

    // how often to clean up stories from the DB
    public static final long CLEANUP_TIME_MILLIS = 6L * 60L * 60L * 1000L;

    // how often to trigger the BG service. slightly longer than how often we will find new stories,
    // to account for the fact that it is approximate, and missing a cycle is bad.
    public static final long BG_SERVICE_CYCLE_MILLIS = AUTO_SYNC_TIME_MILLIS + 30L * 1000L;

    // how often to trigger the job scheduler to sync subscription state.
    public static final long BG_SUBSCRIPTION_SYNC_CYCLE_MILLIS = 24L * 60 * 60 * 1000L;

    // how many total attemtps to make at a single API call
    public static final int MAX_API_TRIES = 3;

    // the base amount for how long to sleep during exponential API failure backoff
    public static final long API_BACKOFF_BASE_MILLIS = 750L;

    // for how long to back off from background syncs after a hard API failure
    public static final long API_BACKGROUND_BACKOFF_MILLIS = 5L * 60L * 1000L;

    // timeouts for API calls, set to something more sane than the default of infinity
    public static final long API_CONN_TIMEOUT_SECONDS = 30L;
    public static final long API_READ_TIMEOUT_SECONDS = 120L;

    // timeouts for image prefetching, which are a bit tighter, since they are only for caching
    public static final long IMAGE_PREFETCH_CONN_TIMEOUT_SECONDS = 10L;
    public static final long IMAGE_PREFETCH_READ_TIMEOUT_SECONDS = 30L;

    // when generating a request for multiple feeds, limit the total number requested to prevent
    // unworkably long URLs
    public static final int MAX_FEED_LIST_SIZE = 250;

    // when reading stories, how many stories worth of buffer to keep loaded ahead of the user
    public static final int READING_STORY_PRELOAD = 10;

    // how many unread stories to fetch via hash at a time
    public static final int UNREAD_FETCH_BATCH_SIZE = 50;

    // how many images to prefetch before updating the countdown UI
    public static final int IMAGE_PREFETCH_BATCH_SIZE = 6;

    // link to app feedback page
    public static final String FEEDBACK_URL = "https://forum.newsblur.com/new-topic?title=Android%3A+&body=";

    // how long to wait for sync threads to shutdown. ideally we would wait the max network timeout,
    // but the system like to force-kill terminating services that take too long, so it is often
    // moot to tune.
    public final static long SHUTDOWN_SLACK_SECONDS = 60L;

    // the maximum duty cycle for expensive background tasks. Tune to <1.0 to force sync loops
    // to pause periodically and yield network/CPU to the foreground UI
    public final static double MAX_BG_DUTY_CYCLE = 0.8;

    // cap duty cycle backoffs to prevent unnecessarily large backoffs
    public final static long DUTY_CYCLE_BACKOFF_CAP_MILLIS = 5L * 1000L;

    // link to the web-based forgot password flow
    public final static String FORGOT_PASWORD_URL = "http://www.newsblur.com/folder_rss/forgot_password";

    // Shiloh photo
    public final static String SHILOH_PHOTO_URL = "https://newsblur.com/media//img/reader/shiloh.jpg";

    // Premium subscription SKU
    public final static String PREMIUM_SKU = "nb.premium.36";

    // Free standard account sites limit
    public final static int FREE_ACCOUNT_SITE_LIMIT = 64;

    // The following keys are used to mark the position of the special meta-folders within
    // the folders array.  Since the ExpandableListView doesn't handle collapsing of views
    // set to View.GONE, we have to totally remove any hidden groups from the group count
    // and adjust all folder indicies accordingly. Fake folders are created with these
    // very unlikely names and layout methods check against them before assuming a row is
    // a normal folder.  All the string comparison is a small price to pay to avoid the
    // alternative of index-counting in a situation where some rows might be disabled.
    public static final String GLOBAL_SHARED_STORIES_GROUP_KEY = "GLOBAL_SHARED_STORIES_GROUP_KEY";
    public static final String ALL_SHARED_STORIES_GROUP_KEY = "ALL_SHARED_STORIES_GROUP_KEY";
    public static final String ALL_STORIES_GROUP_KEY = "ALL_STORIES_GROUP_KEY";
    public static final String INFREQUENT_SITE_STORIES_GROUP_KEY = "INFREQUENT_SITE_STORIES_GROUP_KEY";
    public static final String READ_STORIES_GROUP_KEY = "READ_STORIES_GROUP_KEY";
    public static final String SAVED_STORIES_GROUP_KEY = "SAVED_STORIES_GROUP_KEY";
    public static final String SAVED_SEARCHES_GROUP_KEY = "SAVED_SEARCHES_GROUP_KEY";

}
