package com.newsblur.util;

public class AppConstants {

    // Enables high-volume logging that may be useful for debugging. This should
    // never be enabled for releases, as it not only slows down the app considerably,
    // it will log sensitive info such as passwords!
    public static final boolean VERBOSE_LOG = false;

	public static final int STATE_ALL = 0;
	public static final int STATE_SOME = 1;
	public static final int STATE_BEST = 2;
	
	public static final int REGISTRATION_DEFAULT = 0;
	public static final int REGISTRATION_STARTED = 1;
	public static final int REGISTRATION_COMPLETED = 1;
	
	public static final String FOLDER_PRE = "folder_collapsed";

    // reading view font sizes, in em
	public static final float[] READING_FONT_SIZE = {0.75f, 0.9f, 1.0f, 1.2f, 1.5f, 2.0f};
	
    // the name to give the "root" folder in the local DB since the API does not assign it one.
    // this name should be unique and such that it will sort to the beginning of a list, ideally.
    public static final String ROOT_FOLDER = "0000_TOP_LEVEL_";

    public static final String LAST_APP_VERSION = "LAST_APP_VERSION";

    // a pref for the time we completed the last full sync of the feed/fodler list
    public static final String LAST_SYNC_TIME = "LAST_SYNC_TIME";

    // how long to wait before auto-syncing the feed/folder list
    public static final long AUTO_SYNC_TIME_MILLIS = 10L * 60L * 1000L;

    // how many total attemtps to make at a single API call
    public static final int MAX_API_TRIES = 3;

    // the base amount for how long to sleep during exponential API failure backoff
    public static final long API_BACKOFF_BASE_MILLIS = 500L;

    // when generating a request for multiple feeds, limit the total number requested to prevent
    // unworkably long URLs
    public static final int MAX_FEED_LIST_SIZE = 250;

    // when reading stories, how many stories worth of buffer to keep loaded ahead of the user
    public static final int READING_STORY_PRELOAD = 5;
}
