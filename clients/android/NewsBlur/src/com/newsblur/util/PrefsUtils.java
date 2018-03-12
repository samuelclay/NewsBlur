package com.newsblur.util;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.net.URL;
import java.net.URLConnection;
import java.util.Date;
import java.util.HashSet;
import java.util.Set;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.content.pm.PackageManager.NameNotFoundException;
import android.graphics.Bitmap;
import android.graphics.Bitmap.CompressFormat;
import android.graphics.BitmapFactory;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.Build;
import android.support.v4.content.FileProvider;
import android.util.Log;

import com.newsblur.R;
import com.newsblur.activity.Login;
import com.newsblur.domain.UserDetails;
import com.newsblur.network.APIConstants;
import com.newsblur.util.PrefConstants.ThemeValue;
import com.newsblur.service.NBSyncService;

public class PrefsUtils {

    private PrefsUtils() {} // util class - no instances

	public static void saveCustomServer(Context context, String customServer) {
        if (customServer == null) return;
        if (customServer.length() <= 0) return;
		SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		Editor edit = preferences.edit();
        edit.putString(PrefConstants.PREF_CUSTOM_SERVER, customServer);
		edit.commit();
	}

	public static void saveLogin(Context context, String userName, String cookie) {
		SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		Editor edit = preferences.edit();
		edit.putString(PrefConstants.PREF_COOKIE, cookie);
		edit.putString(PrefConstants.PREF_UNIQUE_LOGIN, userName + "_" + System.currentTimeMillis());
		edit.commit();
        NBSyncService.resumeFromInterrupt();
	}

    public static boolean checkForUpgrade(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        String version = getVersion(context);
        if (version == null) {
            Log.wtf(PrefsUtils.class.getName(), "could not determine app version");
            return false;
        }
        if (AppConstants.VERBOSE_LOG) Log.i(PrefsUtils.class.getName(), "launching version: " + version);

        String oldVersion = prefs.getString(AppConstants.LAST_APP_VERSION, null);
        if ( (oldVersion == null) || (!oldVersion.equals(version)) ) {
            com.newsblur.util.Log.i(PrefsUtils.class.getName(), "detected new version of app:" + version);
            return true;
        }
        return false;

    }

    public static void updateVersion(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        // store the current version
        prefs.edit().putString(AppConstants.LAST_APP_VERSION, getVersion(context)).commit();
        // also make sure we auto-trigger an update, since all data are now gone
        prefs.edit().putLong(AppConstants.LAST_SYNC_TIME, 0L).commit();
    }

    public static String getVersion(Context context) {
        try {
            return context.getPackageManager().getPackageInfo(context.getPackageName(), 0).versionName;
        } catch (NameNotFoundException nnfe) {
            Log.w(PrefsUtils.class.getName(), "could not determine app version");
            return null;
        }
    }

    public static String createFeedbackLink(Context context) {
        StringBuilder s = new StringBuilder(AppConstants.FEEDBACK_URL);
        s.append("<give us some feedback!>%0A%0A%0A");
        String info = getDebugInfo(context);
        s.append(info.replace("\n", "%0A"));
        return s.toString();
    }

    public static void sendLogEmail(Context context) {
        File f = com.newsblur.util.Log.getLogfile();
        if (f == null) return;
        String debugInfo = "Tell us a bit about your problem:\n\n\n\n" + getDebugInfo(context);
        android.net.Uri localPath = FileProvider.getUriForFile(context, "com.newsblur.fileprovider", f);
        Intent i = new Intent(Intent.ACTION_SEND);
        i.setType("*/*");
        i.putExtra(Intent.EXTRA_EMAIL, new String[]{"android@newsblur.com"});
        i.putExtra(Intent.EXTRA_SUBJECT, "Android logs (" + getUserDetails(context).username + ")");
        i.putExtra(Intent.EXTRA_TEXT, debugInfo);
        i.putExtra(Intent.EXTRA_STREAM, localPath);
        if (i.resolveActivity(context.getPackageManager()) != null) {
            context.startActivity(i);
        }
    }

    private static String getDebugInfo(Context context) {
        StringBuilder s = new StringBuilder();
        s.append("app version: ").append(getVersion(context));
        s.append("\n");
        s.append("android version: ").append(Build.VERSION.RELEASE).append(" (" + Build.DISPLAY + ")");
        s.append("\n");
        s.append("device: ").append(Build.MANUFACTURER + " " + Build.MODEL + " (" + Build.BOARD + ")");
        s.append("\n");
        s.append("sqlite version: ").append(FeedUtils.dbHelper.getEngineVersion());
        s.append("\n");
        s.append("username: ").append(getUserDetails(context).username);
        s.append("\n");
        s.append("server: ").append(APIConstants.isCustomServer() ? "default" : "custom");
        s.append("\n");
        s.append("memory: ").append(NBSyncService.isMemoryLow() ? "low" : "normal");
        s.append("\n");
        s.append("speed: ").append(NBSyncService.getSpeedInfo());
        s.append("\n");
        s.append("pending actions: ").append(NBSyncService.getPendingInfo());
        s.append("\n");
        s.append("premium: ");
        if (NBSyncService.isPremium == Boolean.TRUE) {
            s.append("yes");
        } else if (NBSyncService.isPremium == Boolean.FALSE) {
            s.append("no");
        } else {
            s.append("unknown");
        }
        s.append("\n");
        s.append("prefetch: ").append(isOfflineEnabled(context) ? "yes" : "no");
        s.append("\n");
        s.append("notifications: ").append(isEnableNotifications(context) ? "yes" : "no");
        s.append("\n");
        s.append("keepread: ").append(isKeepOldStories(context) ? "yes" : "no");
        s.append("\n");
        s.append("thumbs: ").append(isShowThumbnails(context) ? "yes" : "no");
        s.append("\n");
        return s.toString();
    }

    public static void logout(Context context) {
        NBSyncService.softInterrupt();
        NBSyncService.clearState();

        NotificationUtils.clear(context);

        // wipe the prefs store
        context.getSharedPreferences(PrefConstants.PREFERENCES, 0).edit().clear().commit();

        // wipe the local DB
        FeedUtils.dropAndRecreateTables();

        // reset custom server
        APIConstants.unsetCustomServer();
        
        // prompt for a new login
        Intent i = new Intent(context, Login.class);
        i.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK);
        context.startActivity(i);
    }

    public static void clearPrefsAndDbForLoginAs(Context context) {
        NBSyncService.softInterrupt();
        NBSyncService.clearState();

        // wipe the prefs store except for the cookie and login keys since we need to
        // authenticate further API calls
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Set<String> keys = new HashSet<String>(prefs.getAll().keySet());
        keys.remove(PrefConstants.PREF_COOKIE);
        keys.remove(PrefConstants.PREF_UNIQUE_LOGIN);
        keys.remove(PrefConstants.PREF_CUSTOM_SERVER);
        SharedPreferences.Editor editor = prefs.edit();
        for (String key : keys) {
            editor.remove(key);
        }
        editor.commit();

        // wipe the local DB
        FeedUtils.dropAndRecreateTables();
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

    public static String getCustomServer(Context context) {
		SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		return preferences.getString(PrefConstants.PREF_CUSTOM_SERVER, null);
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

	public static UserDetails getUserDetails(Context context) {
		UserDetails user = new UserDetails();

        if (context == null) return null;
		SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
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

        } catch (Exception e) {
            // this can fail for a huge number of reasons, from storage problems to
            // missing image codecs. if it fails, a placeholder will be used
            Log.e(PrefsUtils.class.getName(), "couldn't save user profile image", e);
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

    private static long getLastVacuumTime(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getLong(PrefConstants.LAST_VACUUM_TIME, 1L);
    }

    public static boolean isTimeToVacuum(Context context) {
        long lastTime = getLastVacuumTime(context);
        long now = (new Date()).getTime();
        return ( (lastTime + AppConstants.VACUUM_TIME_MILLIS) < now );
    }

    public static void updateLastVacuumTime(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        prefs.edit().putLong(PrefConstants.LAST_VACUUM_TIME, (new Date()).getTime()).commit();
    }

    public static boolean isTimeToCleanup(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        long lastTime = prefs.getLong(PrefConstants.LAST_CLEANUP_TIME, 1L);
        long nowTime = (new Date()).getTime();
        if ( (lastTime + AppConstants.CLEANUP_TIME_MILLIS) < nowTime ) {
            return true;
        } else {
            return false;
        }
    }

    public static void updateLastCleanupTime(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        prefs.edit().putLong(PrefConstants.LAST_CLEANUP_TIME, (new Date()).getTime()).commit();
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

    public static StoryListStyle getStoryListStyleForFeed(Context context, String feedId) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return StoryListStyle.valueOf(prefs.getString(PrefConstants.FEED_STORY_LIST_STYLE_PREFIX + feedId, StoryListStyle.LIST.toString()));
    }
    
    public static StoryListStyle getStoryListStyleForFolder(Context context, String folderName) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return StoryListStyle.valueOf(prefs.getString(PrefConstants.FOLDER_STORY_LIST_STYLE_PREFIX + folderName, StoryListStyle.LIST.toString()));
    }
    
    public static void setStoryListStyleForFolder(Context context, String folderName, StoryListStyle newValue) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putString(PrefConstants.FOLDER_STORY_LIST_STYLE_PREFIX + folderName, newValue.toString());
        editor.commit();
    }
    
    public static void setStoryListStyleForFeed(Context context, String feedId, StoryListStyle newValue) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putString(PrefConstants.FEED_STORY_LIST_STYLE_PREFIX + feedId, newValue.toString());
        editor.commit();
    }

    private static StoryOrder getDefaultStoryOrder(SharedPreferences prefs) {
        return StoryOrder.valueOf(prefs.getString(PrefConstants.DEFAULT_STORY_ORDER, StoryOrder.NEWEST.toString()));
    }

    public static StoryOrder getDefaultStoryOrder(Context context) {
        SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return getDefaultStoryOrder(preferences);
    }
    
    private static ReadFilter getDefaultReadFilter(SharedPreferences prefs) {
        return ReadFilter.valueOf(prefs.getString(PrefConstants.DEFAULT_READ_FILTER, ReadFilter.ALL.toString()));
    }

    public static boolean isEnableRowGlobalShared(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.ENABLE_ROW_GLOBAL_SHARED, true);
    }

    public static boolean isEnableRowInfrequent(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.ENABLE_ROW_INFREQUENT_STORIES, true);
    }

    public static boolean showPublicComments(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.SHOW_PUBLIC_COMMENTS, true);
    }
    
    public static float getTextSize(Context context) {
        SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        float storedValue = preferences.getFloat(PrefConstants.PREFERENCE_TEXT_SIZE, 1.0f);
        // some users have wacky, pre-migration values stored that won't render.  If the value is below our
        // minimum size, soft reset to the defaul size.
        if (storedValue < AppConstants.READING_FONT_SIZE[0]) {
            return 1.0f;
        } else {
            return storedValue;
        }
    }

    public static void setTextSize(Context context, float size) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putFloat(PrefConstants.PREFERENCE_TEXT_SIZE, size);
        editor.commit();
    }

    public static float getListTextSize(Context context) {
        SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        float storedValue = preferences.getFloat(PrefConstants.PREFERENCE_LIST_TEXT_SIZE, 1.0f);
        // some users have wacky, pre-migration values stored that won't render.  If the value is below our
        // minimum size, soft reset to the defaul size.
        if (storedValue < AppConstants.LIST_FONT_SIZE[0]) {
            return 1.0f;
        } else {
            return storedValue;
        }
    }

    public static void setListTextSize(Context context, float size) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putFloat(PrefConstants.PREFERENCE_LIST_TEXT_SIZE, size);
        editor.commit();
    }

    public static int getInfrequentCutoff(Context context) {
        SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return preferences.getInt(PrefConstants.PREFERENCE_INFREQUENT_CUTOFF, 30);
    }

    public static void setInfrequentCutoff(Context context, int newValue) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putInt(PrefConstants.PREFERENCE_INFREQUENT_CUTOFF, newValue);
        editor.commit();
    }

    public static DefaultFeedView getDefaultViewModeForFeed(Context context, String feedId) {
        if ((feedId == null) || (feedId.equals(0))) return DefaultFeedView.STORY;
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return DefaultFeedView.valueOf(prefs.getString(PrefConstants.FEED_DEFAULT_FEED_VIEW_PREFIX + feedId, getDefaultFeedView().toString()));
    }

    public static void setDefaultViewModeForFeed(Context context, String feedId, DefaultFeedView newValue) {
        if ((feedId == null) || (feedId.equals(0))) return;
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putString(PrefConstants.FEED_DEFAULT_FEED_VIEW_PREFIX + feedId, newValue.toString());
        editor.commit();
    }

    public static StoryOrder getStoryOrder(Context context, FeedSet fs) {
        if (fs.isAllNormal()) {
            return getStoryOrderForFolder(context, PrefConstants.ALL_STORIES_FOLDER_NAME);
        } else if (fs.getSingleFeed() != null) {
            return getStoryOrderForFeed(context, fs.getSingleFeed());
        } else if (fs.getMultipleFeeds() != null) {
            return getStoryOrderForFolder(context, fs.getFolderName());
        } else if (fs.isAllSocial()) {
            return getStoryOrderForFolder(context, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME);
        } else if (fs.getSingleSocialFeed() != null) {
            return getStoryOrderForFeed(context, fs.getSingleSocialFeed().getKey());
        } else if (fs.getMultipleSocialFeeds() != null) {
            throw new IllegalArgumentException( "requests for multiple social feeds not supported" );
        } else if (fs.isAllRead()) {
            // dummy value, not really used
            return StoryOrder.NEWEST;
        } else if (fs.isAllSaved()) {
            return getStoryOrderForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME);
        } else if (fs.getSingleSavedTag() != null) {
            return getStoryOrderForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME);
        } else if (fs.isGlobalShared()) {
            return StoryOrder.NEWEST;
        } else if (fs.isInfrequent()) {
            return getStoryOrderForFolder(context, PrefConstants.INFREQUENT_FOLDER_NAME);
        } else {
            throw new IllegalArgumentException( "unknown type of feed set" );
        }
    }

    public static void updateStoryOrder(Context context, FeedSet fs, StoryOrder newOrder) {
        if (fs.isAllNormal()) {
            setStoryOrderForFolder(context, PrefConstants.ALL_STORIES_FOLDER_NAME, newOrder);
        } else if (fs.getSingleFeed() != null) {
            setStoryOrderForFeed(context, fs.getSingleFeed(), newOrder);
        } else if (fs.getMultipleFeeds() != null) {
            setStoryOrderForFolder(context, fs.getFolderName(), newOrder);
        } else if (fs.isAllSocial()) {
            setStoryOrderForFolder(context, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME, newOrder);
        } else if (fs.getSingleSocialFeed() != null) {
            setStoryOrderForFeed(context, fs.getSingleSocialFeed().getKey(), newOrder);
        } else if (fs.getMultipleSocialFeeds() != null) {
            throw new IllegalArgumentException( "multiple social feeds not supported" );
        } else if (fs.isAllRead()) {
            throw new IllegalArgumentException( "AllRead FeedSet type has fixed ordering" );
        } else if (fs.isAllSaved()) {
            setStoryOrderForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME, newOrder);
        } else if (fs.getSingleSavedTag() != null) {
            setStoryOrderForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME, newOrder);
        } else if (fs.isGlobalShared()) {
            throw new IllegalArgumentException( "GlobalShared FeedSet type has fixed ordering" );
        } else if (fs.isInfrequent()) {
            setStoryOrderForFolder(context, PrefConstants.INFREQUENT_FOLDER_NAME, newOrder);
        } else {
            throw new IllegalArgumentException( "unknown type of feed set" );
        }
    }

    public static ReadFilter getReadFilter(Context context, FeedSet fs) {
        if (fs.isAllNormal()) {
            return getReadFilterForFolder(context, PrefConstants.ALL_STORIES_FOLDER_NAME);
        } else if (fs.getSingleFeed() != null) {
            return getReadFilterForFeed(context, fs.getSingleFeed());
        } else if (fs.getMultipleFeeds() != null) {
            return getReadFilterForFolder(context, fs.getFolderName());
        } else if (fs.isAllSocial()) {
            return getReadFilterForFolder(context, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME);
        } else if (fs.getSingleSocialFeed() != null) {
            return getReadFilterForFeed(context, fs.getSingleSocialFeed().getKey());
        } else if (fs.getMultipleSocialFeeds() != null) {
            throw new IllegalArgumentException( "requests for multiple social feeds not supported" );
        } else if (fs.isAllRead()) {
            // it would make no sense to look for read stories in unread-only
            return ReadFilter.ALL;
        } else if (fs.isAllSaved()) {
            // saved stories view doesn't track read status
            return ReadFilter.ALL;
        } else if (fs.getSingleSavedTag() != null) {
            // saved stories view doesn't track read status
            return ReadFilter.ALL;
        } else if (fs.isGlobalShared()) {
            return getReadFilterForFolder(context, PrefConstants.GLOBAL_SHARED_STORIES_FOLDER_NAME);
        } else if (fs.isInfrequent()) {
            return getReadFilterForFolder(context, PrefConstants.INFREQUENT_FOLDER_NAME);
        }
        throw new IllegalArgumentException( "unknown type of feed set" );
    }

    public static void updateReadFilter(Context context, FeedSet fs, ReadFilter newFilter) {
        if (fs.isAllNormal()) {
            setReadFilterForFolder(context, PrefConstants.ALL_STORIES_FOLDER_NAME, newFilter);
        } else if (fs.getSingleFeed() != null) {
            setReadFilterForFeed(context, fs.getSingleFeed(), newFilter);
        } else if (fs.getMultipleFeeds() != null) {
            setReadFilterForFolder(context, fs.getFolderName(), newFilter);
        } else if (fs.isAllSocial()) {
            setReadFilterForFolder(context, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME, newFilter);
        } else if (fs.getSingleSocialFeed() != null) {
            setReadFilterForFeed(context, fs.getSingleSocialFeed().getKey(), newFilter);
        } else if (fs.getMultipleSocialFeeds() != null) {
            setReadFilterForFolder(context, fs.getFolderName(), newFilter);
        } else if (fs.isAllRead()) {
            throw new IllegalArgumentException( "read filter not applicable to this type of feedset");
        } else if (fs.isAllSaved()) {
            throw new IllegalArgumentException( "read filter not applicable to this type of feedset");
        } else if (fs.getSingleSavedTag() != null) {
            throw new IllegalArgumentException( "read filter not applicable to this type of feedset");
        } else if (fs.isGlobalShared()) {
            setReadFilterForFolder(context, PrefConstants.GLOBAL_SHARED_STORIES_FOLDER_NAME, newFilter);
        } else if (fs.isInfrequent()) {
            setReadFilterForFolder(context, PrefConstants.INFREQUENT_FOLDER_NAME, newFilter);
        } else {
            throw new IllegalArgumentException( "unknown type of feed set" );
        }
    } 

    public static StoryListStyle getStoryListStyle(Context context, FeedSet fs) {
        if (fs.isAllNormal()) {
            return getStoryListStyleForFolder(context, PrefConstants.ALL_STORIES_FOLDER_NAME);
        } else if (fs.getSingleFeed() != null) {
            return getStoryListStyleForFeed(context, fs.getSingleFeed());
        } else if (fs.getMultipleFeeds() != null) {
            return getStoryListStyleForFolder(context, fs.getFolderName());
        } else if (fs.isAllSocial()) {
            return getStoryListStyleForFolder(context, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME);
        } else if (fs.getSingleSocialFeed() != null) {
            return getStoryListStyleForFeed(context, fs.getSingleSocialFeed().getKey());
        } else if (fs.getMultipleSocialFeeds() != null) {
            throw new IllegalArgumentException( "requests for multiple social feeds not supported" );
        } else if (fs.isAllRead()) {
            return getStoryListStyleForFolder(context, PrefConstants.READ_STORIES_FOLDER_NAME);
        } else if (fs.isAllSaved()) {
            return getStoryListStyleForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME);
        } else if (fs.getSingleSavedTag() != null) {
            return getStoryListStyleForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME);
        } else if (fs.isGlobalShared()) {
            return getStoryListStyleForFolder(context, PrefConstants.GLOBAL_SHARED_STORIES_FOLDER_NAME);
        } else if (fs.isInfrequent()) {
            return getStoryListStyleForFolder(context, PrefConstants.INFREQUENT_FOLDER_NAME);
        } else {
            throw new IllegalArgumentException( "unknown type of feed set" );
        }
    }

    public static void updateStoryListStyle(Context context, FeedSet fs, StoryListStyle newListStyle) {
        if (fs.isAllNormal()) {
            setStoryListStyleForFolder(context, PrefConstants.ALL_STORIES_FOLDER_NAME, newListStyle);
        } else if (fs.getSingleFeed() != null) {
            setStoryListStyleForFeed(context, fs.getSingleFeed(), newListStyle);
        } else if (fs.getMultipleFeeds() != null) {
            setStoryListStyleForFolder(context, fs.getFolderName(), newListStyle);
        } else if (fs.isAllSocial()) {
            setStoryListStyleForFolder(context, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME, newListStyle);
        } else if (fs.getSingleSocialFeed() != null) {
            setStoryListStyleForFeed(context, fs.getSingleSocialFeed().getKey(), newListStyle);
        } else if (fs.getMultipleSocialFeeds() != null) {
            throw new IllegalArgumentException( "multiple social feeds not supported" );
        } else if (fs.isAllRead()) {
            setStoryListStyleForFolder(context, PrefConstants.READ_STORIES_FOLDER_NAME, newListStyle);
        } else if (fs.isAllSaved()) {
            setStoryListStyleForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME, newListStyle);
        } else if (fs.getSingleSavedTag() != null) {
            setStoryListStyleForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME, newListStyle);
        } else if (fs.isGlobalShared()) {
            setStoryListStyleForFolder(context, PrefConstants.GLOBAL_SHARED_STORIES_FOLDER_NAME, newListStyle);
        } else if (fs.isInfrequent()) {
            setStoryListStyleForFolder(context, PrefConstants.INFREQUENT_FOLDER_NAME, newListStyle);
        } else {
            throw new IllegalArgumentException( "unknown type of feed set" );
        }
    }

    private static DefaultFeedView getDefaultFeedView() {
        return DefaultFeedView.STORY;
    }

    public static boolean enterImmersiveReadingModeOnSingleTap(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.READING_ENTER_IMMERSIVE_SINGLE_TAP, false);
    }

    public static boolean isShowContentPreviews(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.STORIES_SHOW_PREVIEWS, true);
    }

    public static boolean isShowThumbnails(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.STORIES_SHOW_THUMBNAILS,  true);
    }

    public static boolean isAutoOpenFirstUnread(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.STORIES_AUTO_OPEN_FIRST, false);
    }

    public static boolean isMarkReadOnScroll(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.STORIES_MARK_READ_ON_SCROLL, false);
    }

    public static boolean isOfflineEnabled(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.ENABLE_OFFLINE, false);
    }

    public static boolean isImagePrefetchEnabled(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.ENABLE_IMAGE_PREFETCH, false);
    }

    /**
     * Compares the user's setting for when background data use is allowed against the
     * current network status and sees if it is okay to sync.
     */
    public static boolean isBackgroundNetworkAllowed(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        String mode = prefs.getString(PrefConstants.NETWORK_SELECT, PrefConstants.NETWORK_SELECT_NOMONONME);

        ConnectivityManager connMgr = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo activeInfo = connMgr.getActiveNetworkInfo();

        // if we aren't even online, there is no way bg data will work
        if ((activeInfo == null) || (!activeInfo.isConnected())) return false;

        // if user restricted use of mobile nets, make sure we aren't on one
        int type = activeInfo.getType();
        if (mode.equals(PrefConstants.NETWORK_SELECT_NOMO)) {
            if (! ((type == ConnectivityManager.TYPE_WIFI) || (type == ConnectivityManager.TYPE_ETHERNET))) {
                return false;
            }
        } else if (mode.equals(PrefConstants.NETWORK_SELECT_NOMONONME)) {
            if (! ((type == ConnectivityManager.TYPE_WIFI) || (type == ConnectivityManager.TYPE_ETHERNET))) {
                return false;
            }
            if (connMgr.isActiveNetworkMetered()) {
                return false;
            }
        }

        return true;
    }

    public static boolean isKeepOldStories(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.KEEP_OLD_STORIES, false);
    }

    public static long getMaxCachedAgeMillis(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        String val = prefs.getString(PrefConstants.CACHE_AGE_SELECT, PrefConstants.CACHE_AGE_SELECT_30D);
        if (val.equals(PrefConstants.CACHE_AGE_SELECT_2D)) return PrefConstants.CACHE_AGE_VALUE_2D;
        if (val.equals(PrefConstants.CACHE_AGE_SELECT_7D)) return PrefConstants.CACHE_AGE_VALUE_7D;
        if (val.equals(PrefConstants.CACHE_AGE_SELECT_14D)) return PrefConstants.CACHE_AGE_VALUE_14D;
        if (val.equals(PrefConstants.CACHE_AGE_SELECT_30D)) return PrefConstants.CACHE_AGE_VALUE_30D;
        return PrefConstants.CACHE_AGE_VALUE_30D;
    }

    public static void applyThemePreference(Activity activity) {
        ThemeValue value = getSelectedTheme(activity);
        if (value == ThemeValue.LIGHT) {
            activity.setTheme(R.style.NewsBlurTheme);
        } else if (value == ThemeValue.DARK) {
            activity.setTheme(R.style.NewsBlurDarkTheme);
        } else if (value == ThemeValue.BLACK) {
            activity.setTheme(R.style.NewsBlurBlackTheme);
        }
    }

    public static ThemeValue getSelectedTheme(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        String value = prefs.getString(PrefConstants.THEME, ThemeValue.LIGHT.name());
        // check for legacy hard-coded values. this can go away once installs of v152 or earlier are minimized
        if (value.equals("light")) {    
            setSelectedTheme(context, ThemeValue.LIGHT);
            return ThemeValue.LIGHT;
        }
        if (value.equals("dark")) {    
            setSelectedTheme(context, ThemeValue.DARK);
            return ThemeValue.DARK;
        }
        return ThemeValue.valueOf(value);
    }

    public static void setSelectedTheme(Context context, ThemeValue value) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putString(PrefConstants.THEME, value.name());
        editor.commit();
    }

    public static StateFilter getStateFilter(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return StateFilter.valueOf(prefs.getString(PrefConstants.STATE_FILTER, StateFilter.SOME.toString()));
    }

    public static void setStateFilter(Context context, StateFilter newValue) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putString(PrefConstants.STATE_FILTER, newValue.toString());
        editor.commit();
    }

    public static VolumeKeyNavigation getVolumeKeyNavigation(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return VolumeKeyNavigation.valueOf(prefs.getString(PrefConstants.VOLUME_KEY_NAVIGATION, VolumeKeyNavigation.OFF.toString()));
    }

    public static MarkAllReadConfirmation getMarkAllReadConfirmation(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return MarkAllReadConfirmation.valueOf(prefs.getString(PrefConstants.MARK_ALL_READ_CONFIRMATION, MarkAllReadConfirmation.FOLDER_ONLY.toString()));
    }

    public static boolean isConfirmMarkRangeRead(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.MARK_RANGE_READ_CONFIRMATION, false);
    }

    public static GestureAction getLeftToRightGestureAction(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return GestureAction.valueOf(prefs.getString(PrefConstants.LTR_GESTURE_ACTION, GestureAction.GEST_ACTION_MARKREAD.toString()));
    }

    public static GestureAction getRightToLeftGestureAction(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return GestureAction.valueOf(prefs.getString(PrefConstants.RTL_GESTURE_ACTION, GestureAction.GEST_ACTION_MARKUNREAD.toString()));
    }

    public static boolean isEnableNotifications(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.ENABLE_NOTIFICATIONS, false);
    }

    public static boolean isBackgroundNeeded(Context context) {
        return (isEnableNotifications(context) || isOfflineEnabled(context));
    }

    public static Font getFont(Context context) {
        return Font.getFont(getFontString(context));
    }

    public static String getFontString(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getString(PrefConstants.READING_FONT, Font.DEFAULT.toString());
    }

    public static void setFontString(Context context, String newValue) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putString(PrefConstants.READING_FONT, newValue);
        editor.commit();
    }
}
