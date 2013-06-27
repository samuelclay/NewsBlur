package com.newsblur.util;

public class AppConstants {
	public static final int STATE_ALL = 0;
	public static final int STATE_SOME = 1;
	public static final int STATE_BEST = 2;
	
	public static final int REGISTRATION_DEFAULT = 0;
	public static final int REGISTRATION_STARTED = 1;
	public static final int REGISTRATION_COMPLETED = 1;
	
	public static final String FOLDER_PRE = "folder_collapsed";
	public static final String NEWSBLUR_URL = "http://www.newsblur.com";
	public static final float FONT_SIZE_LOWER_BOUND = 1.0f;
	public static final float FONT_SIZE_INCREMENT_FACTOR = 5;
	
    // the name to give the "root" folder in the local DB since the API does not assign it one.
    // this name should be unique and such that it will sort to the beginning of a list, ideally.
    public static final String ROOT_FOLDER = "0000_TOP_LEVEL_";

    public static final String LAST_APP_VERSION = "LAST_APP_VERSION";

    // the max number of mark-as-read ops to batch up before flushing to the server
    public static final int MAX_MARK_READ_BATCH = 5;

    // a pref for the time we completed the last full sync of the feed/fodler list
    public static final String LAST_SYNC_TIME = "LAST_SYNC_TIME";

    // how long to wait before auto-syncing the feed/folder list
    public static final long AUTO_SYNC_TIME_MILLIS = 10L * 60L * 1000L;
}
