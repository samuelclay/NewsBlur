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

    // reading view font sizes. in em
	public static final float[] READING_FONT_SIZE = {0.75f, 0.9f, 1.0f, 1.2f, 1.5f, 2.0f};

    // story list view font sizes. as a fraction of the default font sizes used
	public static final float[] LIST_FONT_SIZE = {0.7f, 0.85f, 1.0f, 1.2f, 1.4f, 1.8f};
	
    // the name to give the "root" folder in the local DB since the API does not assign it one.
    // this name should be unique and such that it will sort to the beginning of a list, ideally.
    public static final String ROOT_FOLDER = "0000_TOP_LEVEL_";

    public static final String LAST_APP_VERSION = "LAST_APP_VERSION";

    // a pref for the time we completed the last full sync of the feed/fodler list
    public static final String LAST_SYNC_TIME = "LAST_SYNC_TIME";

    // how long to wait before auto-syncing the feed/folder list
    public static final long AUTO_SYNC_TIME_MILLIS = 20L * 60L * 1000L;

    // how often to rebuild the DB
    public static final long VACUUM_TIME_MILLIS = 12L * 60L * 60L * 1000L;

    // how often to clean up the DB
    public static final long CLEANUP_TIME_MILLIS = 3L * 60L * 60L * 1000L;

    // how often to trigger the BG service. slightly longer than how often we will find new stories,
    // to account for the fact that it is approximate, and missing a cycle is bad.
    public static final long BG_SERVICE_CYCLE_MILLIS = AUTO_SYNC_TIME_MILLIS + 30L * 1000L;

    // how many total attemtps to make at a single API call
    public static final int MAX_API_TRIES = 3;

    // the base amount for how long to sleep during exponential API failure backoff
    public static final long API_BACKOFF_BASE_MILLIS = 750L;

    // for how long to back off from background syncs after a hard API failure
    public static final long API_BACKGROUND_BACKOFF_MILLIS = 5L * 60L * 1000L;

    // timeouts for API calls, set to something more sane than the default of infinity
    public static final long API_CONN_TIMEOUT_SECONDS = 60L;
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

    // should the feedback link be enabled (read: is this a beta?)
    public static final boolean ENABLE_FEEDBACK = true;

    // link to app feedback page
    public static final String FEEDBACK_URL = "https://getsatisfaction.com/newsblur/topics/new/add_details?topic[subject]=Android%3A+&topic[categories][][id]=80957&topic[type]=question&topic[content]=";

    // how long to wait for sync threads to shutdown. ideally we would wait the max network timeout,
    // but the system like to force-kill terminating services that take too long, so it is often
    // moot to tune.
    public final static long SHUTDOWN_SLACK_SECONDS = 60L;

    // the maximum duty cycle for expensive background tasks. Tune to <1.0 to force sync loops
    // to pause periodically and not peg the network/CPU
    public final static double MAX_BG_DUTY_CYCLE = 0.9;

    // cap duty cycle backoffs to prevent unnecessarily large backoffs
    public final static long DUTY_CYCLE_BACKOFF_CAP_MILLIS = 5L * 1000L;

    // link to the web-based forgot password flow
    public final static String FORGOT_PASWORD_URL = "http://www.newsblur.com/folder_rss/forgot_password";

}
