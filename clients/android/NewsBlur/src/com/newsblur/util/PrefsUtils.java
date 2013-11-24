package com.newsblur.util;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.net.URLConnection;
import java.util.Date;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.content.pm.PackageManager.NameNotFoundException;
import android.graphics.Bitmap;
import android.graphics.Bitmap.CompressFormat;
import android.graphics.BitmapFactory;
import android.util.Log;

import com.newsblur.activity.Login;
import com.newsblur.database.BlurDatabase;
import com.newsblur.domain.UserDetails;

public class PrefsUtils {

	public static void saveLogin(final Context context, final String userName, final String cookie) {
		final SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		final Editor edit = preferences.edit();
		edit.putString(PrefConstants.PREF_COOKIE, cookie);
		edit.putString(PrefConstants.PREF_UNIQUE_LOGIN, userName + "_" + System.currentTimeMillis());
		edit.commit();
	}

    /**
     * Check to see if this is the first launch of the app after an upgrade, in which case
     * we clear the DB to prevent bugs associated with non-forward-compatibility.
     */
    public static void checkForUpgrade(Context context) {

        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);

        String version;
        try {
            version = context.getPackageManager().getPackageInfo(context.getPackageName(), 0).versionName;
        } catch (NameNotFoundException nnfe) {
            Log.w(PrefsUtils.class.getName(), "could not determine app version");
            return;
        }
        Log.i(PrefsUtils.class.getName(), "launching version: " + version);

        String oldVersion = prefs.getString(AppConstants.LAST_APP_VERSION, null);
        if ( (oldVersion == null) || (!oldVersion.equals(version)) ) {
            Log.i(PrefsUtils.class.getName(), "detected new version of app, clearing local data");
            // wipe the local DB
            BlurDatabase databaseHelper = new BlurDatabase(context.getApplicationContext());
            databaseHelper.dropAndRecreateTables();
            // store the current version
            prefs.edit().putString(AppConstants.LAST_APP_VERSION, version).commit();
        }

    }

    public static void logout(Context context) {

        // TODO: stop or wait for any BG processes

        // wipe the prefs store
        context.getSharedPreferences(PrefConstants.PREFERENCES, 0).edit().clear().commit();
        
        // wipe the local DB
        BlurDatabase databaseHelper = new BlurDatabase(context.getApplicationContext());
        databaseHelper.dropAndRecreateTables();
        
        // prompt for a new login
        Intent i = new Intent(context, Login.class);
        i.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
        context.startActivity(i);

    }

	/**
	 * Retrieves the current unique login key. This key will be unique for each
	 * login. If this login key doesn't match the login key you have then assume
	 * the user is logged out
	 */
	public static String getUniqueLoginKey(final Context context) {
		final SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		return preferences.getString(PrefConstants.PREF_UNIQUE_LOGIN, null);
	}

	public static void saveUserDetails(final Context context, final UserDetails profile) {
		final SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		final Editor edit = preferences.edit();
		edit.putInt(PrefConstants.USER_AVERAGE_STORIES_PER_MONTH, profile.averageStoriesPerMonth);
		edit.putString(PrefConstants.USER_BIO, profile.bio);
		edit.putString(PrefConstants.USER_FEED_ADDRESS, profile.feedAddress);
		edit.putString(PrefConstants.USER_FEED_TITLE, profile.feedTitle);
		edit.putInt(PrefConstants.USER_FOLLOWER_COUNT, profile.followerCount);
		edit.putInt(PrefConstants.USER_FOLLOWING_COUNT, profile.followingCount);
		edit.putString(PrefConstants.USER_ID, profile.userId);
		edit.putString(PrefConstants.USER_LOCATION, profile.location);
		edit.putString(PrefConstants.USER_PHOTO_SERVICE, profile.photoService);
		edit.putString(PrefConstants.USER_PHOTO_URL, profile.photoUrl);
		edit.putInt(PrefConstants.USER_SHARED_STORIES_COUNT, profile.sharedStoriesCount);
		edit.putInt(PrefConstants.USER_STORIES_LAST_MONTH, profile.storiesLastMonth);
		edit.putInt(PrefConstants.USER_SUBSCRIBER_COUNT, profile.subscriptionCount);
		edit.putString(PrefConstants.USER_USERNAME, profile.username);
		edit.putString(PrefConstants.USER_WEBSITE, profile.website);
		edit.commit();
		saveUserImage(context, profile.photoUrl);
	}

	public static UserDetails getUserDetails(final Context context) {
		UserDetails user = new UserDetails();

		final SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		user.averageStoriesPerMonth = preferences.getInt(PrefConstants.USER_AVERAGE_STORIES_PER_MONTH, 0);
		user.bio = preferences.getString(PrefConstants.USER_BIO, null);
		user.feedAddress = preferences.getString(PrefConstants.USER_FEED_ADDRESS, null);
		user.feedTitle = preferences.getString(PrefConstants.USER_FEED_TITLE, null);
		user.followerCount = preferences.getInt(PrefConstants.USER_FOLLOWER_COUNT, 0);
		user.followingCount = preferences.getInt(PrefConstants.USER_FOLLOWING_COUNT, 0);
		user.id =  preferences.getString(PrefConstants.USER_ID, null);
		user.location = preferences.getString(PrefConstants.USER_LOCATION, null);
		user.photoService = preferences.getString(PrefConstants.USER_PHOTO_SERVICE, null);
		user.photoUrl = preferences.getString(PrefConstants.USER_PHOTO_URL, null);
		user.sharedStoriesCount = preferences.getInt(PrefConstants.USER_SHARED_STORIES_COUNT, 0);
		user.storiesLastMonth = preferences.getInt(PrefConstants.USER_STORIES_LAST_MONTH, 0);
		user.subscriptionCount = preferences.getInt(PrefConstants.USER_SUBSCRIBER_COUNT, 0);
		user.username = preferences.getString(PrefConstants.USER_USERNAME, null);
		user.website = preferences.getString(PrefConstants.USER_WEBSITE, null);

		return user;
	}

	private static void saveUserImage(final Context context, String pictureUrl) {
		Bitmap bitmap = null;
		try {
			URL url = new URL(pictureUrl);
			URLConnection connection;
			connection = url.openConnection();
			connection.setUseCaches(true);
			bitmap = BitmapFactory.decodeStream( (InputStream) connection.getContent());

			File file = context.getCacheDir();
			File imageFile = new File(file.getPath() + "/userProfilePicture");
			bitmap.compress(CompressFormat.PNG, 100, new FileOutputStream(imageFile));

		} catch (IOException e) {
			e.printStackTrace();
		}
	}

	public static Bitmap getUserImage(final Context context) {
		if (context != null) {
			return BitmapFactory.decodeFile(context.getCacheDir().getPath() + "/userProfilePicture");
		} else {
			return null;
		}
	}

    /**
     * Check to see if it has been sufficiently long since the last sync of the feed/folder
     * data to justify automatically syncing again.
     */
    public static boolean isTimeToAutoSync(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        long lastTime = prefs.getLong(AppConstants.LAST_SYNC_TIME, 1L);
        return ( (lastTime + AppConstants.AUTO_SYNC_TIME_MILLIS) < (new Date()).getTime() );
    }

    /**
     * Make note that a sync of the feed/folder list has been completed, so we can track
     * how long it has been until another is needed.
     */
    public static void updateLastSyncTime(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        prefs.edit().putLong(AppConstants.LAST_SYNC_TIME, (new Date()).getTime()).commit();
    }

    public static StoryOrder getStoryOrderForFeed(Context context, String feedId) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return StoryOrder.valueOf(prefs.getString(PrefConstants.FEED_STORY_ORDER_PREFIX + feedId, getDefaultStoryOrder(prefs).toString()));
    }
    
    public static StoryOrder getStoryOrderForFolder(Context context, String folderName) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return StoryOrder.valueOf(prefs.getString(PrefConstants.FOLDER_STORY_ORDER_PREFIX + folderName, getDefaultStoryOrder(prefs).toString()));
    }
    
    public static ReadFilter getReadFilterForFeed(Context context, String feedId) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return ReadFilter.valueOf(prefs.getString(PrefConstants.FEED_READ_FILTER_PREFIX + feedId, getDefaultReadFilter(prefs).toString()));
    }
    
    public static ReadFilter getReadFilterForFolder(Context context, String folderName) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return ReadFilter.valueOf(prefs.getString(PrefConstants.FOLDER_READ_FILTER_PREFIX + folderName, getDefaultReadFilter(prefs).toString()));
    }

    public static void setStoryOrderForFolder(Context context, String folderName, StoryOrder newValue) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putString(PrefConstants.FOLDER_STORY_ORDER_PREFIX + folderName, newValue.toString());
        editor.commit();
    }
    
    public static void setStoryOrderForFeed(Context context, String feedId, StoryOrder newValue) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putString(PrefConstants.FEED_STORY_ORDER_PREFIX + feedId, newValue.toString());
        editor.commit();
    }
    
    public static void setReadFilterForFolder(Context context, String folderName, ReadFilter newValue) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putString(PrefConstants.FOLDER_READ_FILTER_PREFIX + folderName, newValue.toString());
        editor.commit();
    }
    
    public static void setReadFilterForFeed(Context context, String feedId, ReadFilter newValue) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putString(PrefConstants.FEED_READ_FILTER_PREFIX + feedId, newValue.toString());
        editor.commit();
    }
    
    private static StoryOrder getDefaultStoryOrder(SharedPreferences prefs) {
        return StoryOrder.valueOf(prefs.getString(PrefConstants.DEFAULT_STORY_ORDER, StoryOrder.NEWEST.toString()));
    }
    
    private static ReadFilter getDefaultReadFilter(SharedPreferences prefs) {
        return ReadFilter.valueOf(prefs.getString(PrefConstants.DEFAULT_READ_FILTER, ReadFilter.ALL.toString()));
    }

    public static boolean showPublicComments(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.SHOW_PUBLIC_COMMENTS, true);
    }
    
    public static float getTextSize(Context context) {
        SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return preferences.getFloat(PrefConstants.PREFERENCE_TEXT_SIZE, 0.5f);
    }

    public static void setTextSize(Context context, float size) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putFloat(PrefConstants.PREFERENCE_TEXT_SIZE, size);
        editor.commit();
    }
}
