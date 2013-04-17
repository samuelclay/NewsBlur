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
}
