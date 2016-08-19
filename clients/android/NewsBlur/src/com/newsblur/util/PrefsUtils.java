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
import android.util.Log;

import com.newsblur.R;
import com.newsblur.activity.Login;
import com.newsblur.domain.UserDetails;
import com.newsblur.service.NBSyncService;

public class PrefsUtils {

    private PrefsUtils() {} // util class - no instances

	public static void saveLogin(final Context context, final String userName, final String cookie) {
        NBSyncService.resumeFromInterrupt();
		final SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		final Editor edit = preferences.edit();
		edit.putString(PrefConstants.PREF_COOKIE, cookie);
		edit.putString(PrefConstants.PREF_UNIQUE_LOGIN, userName + "_" + System.currentTimeMillis());
		edit.commit();
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
            Log.i(PrefsUtils.class.getName(), "detected new version of app:" + version);
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
        s.append("<give us some feedback!>%0A%0A");
        s.append("%0Aapp version: ").append(getVersion(context));
        s.append("%0Aandroid version: ").append(Build.VERSION.RELEASE).append(" (" + Build.DISPLAY + ")");
        s.append("%0Adevice: ").append(Build.MANUFACTURER + "+" + Build.MODEL + "+(" + Build.BOARD + ")");
        s.append("%0Asqlite version: ").append(FeedUtils.dbHelper.getEngineVersion());
        s.append("%0Ausername: ").append(getUserDetails(context).username);
        s.append("%0Amemory: ").append(NBSyncService.isMemoryLow() ? "low" : "normal");
        s.append("%0Aspeed: ").append(NBSyncService.getSpeedInfo());
        s.append("%0Apending actions: ").append(NBSyncService.getPendingInfo());
        s.append("%0Apremium: ");
        if (NBSyncService.isPremium == Boolean.TRUE) {
            s.append("yes");
        } else if (NBSyncService.isPremium == Boolean.FALSE) {
            s.append("no");
        } else {
            s.append("unknown");
        }
        s.append("%0Aprefetch: ").append(isOfflineEnabled(context) ? "yes" : "no");
        s.append("%0Akeepread: ").append(isKeepOldStories(context) ? "yes" : "no");
        return s.toString();
    }

    public static void logout(Context context) {
        NBSyncService.softInterrupt();
        NBSyncService.clearState();

        // wipe the prefs store
        context.getSharedPreferences(PrefConstants.PREFERENCES, 0).edit().clear().commit();

        // wipe the local DB
        FeedUtils.dropAndRecreateTables();
        
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
        return ( (lastTime + AppConstants.CLEANUP_TIME_MILLIS) < (new Date()).getTime() );
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

    public static DefaultFeedView getDefaultFeedViewForFeed(Context context, String feedId) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return DefaultFeedView.valueOf(prefs.getString(PrefConstants.FEED_DEFAULT_FEED_VIEW_PREFIX + feedId, getDefaultFeedView().toString()));
    }

    public static DefaultFeedView getDefaultFeedViewForFolder(Context context, String folderName) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return DefaultFeedView.valueOf(prefs.getString(PrefConstants.FOLDER_DEFAULT_FEED_VIEW_PREFIX + folderName, getDefaultFeedView().toString()));
    }

    public static void setDefaultFeedViewForFolder(Context context, String folderName, DefaultFeedView newValue) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putString(PrefConstants.FOLDER_DEFAULT_FEED_VIEW_PREFIX + folderName, newValue.toString());
        editor.commit();
    }

    public static void setDefaultFeedViewForFeed(Context context, String feedId, DefaultFeedView newValue) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        Editor editor = prefs.edit();
        editor.putString(PrefConstants.FEED_DEFAULT_FEED_VIEW_PREFIX + feedId, newValue.toString());
        editor.commit();
    }

    public static DefaultFeedView getDefaultFeedView(Context context, FeedSet fs) {
		if (fs.isAllSaved()) {
            return getDefaultFeedViewForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME);
        } else if (fs.getSingleSavedTag() != null) {
            return getDefaultFeedViewForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME);
        } else if (fs.isGlobalShared()) {
            return getDefaultFeedViewForFolder(context, PrefConstants.GLOBAL_SHARED_STORIES_FOLDER_NAME);
        } else if (fs.isAllSocial()) {
            return getDefaultFeedViewForFolder(context, PrefConstants.ALL_SHARED_STORIES_FOLDER_NAME);
        } else if (fs.isAllNormal()) {
            return getDefaultFeedViewForFolder(context, PrefConstants.ALL_STORIES_FOLDER_NAME);
        } else if (fs.isFolder()) {
            return getDefaultFeedViewForFolder(context, fs.getFolderName());
        } else if (fs.getSingleFeed() != null) {
            return getDefaultFeedViewForFeed(context, fs.getSingleFeed());
        } else if (fs.getSingleSocialFeed() != null) {
            return getDefaultFeedViewForFeed(context, fs.getSingleSocialFeed().getKey());
        } else if (fs.isAllRead()) {
            return getDefaultFeedViewForFolder(context, PrefConstants.READ_STORIES_FOLDER_NAME);
        } else {
            return DefaultFeedView.STORY;
        }
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
            // dummy value, not really used
            return ReadFilter.ALL;
        } else if (fs.isAllSaved()) {
            return getReadFilterForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME);
        } else if (fs.getSingleSavedTag() != null) {
            return getReadFilterForFolder(context, PrefConstants.SAVED_STORIES_FOLDER_NAME);
        } else if (fs.isGlobalShared()) {
            return ReadFilter.UNREAD;
        }
        throw new IllegalArgumentException( "unknown type of feed set" );
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
        return prefs.getBoolean(PrefConstants.STORIES_SHOW_THUMBNAILS, false);
    }

    public static boolean isAutoOpenFirstUnread(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.STORIES_AUTO_OPEN_FIRST, false);
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
        String mode = prefs.getString(PrefConstants.NETWORK_SELECT, PrefConstants.NETWORK_SELECT_NOMO);

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
        }

        return true;
    }

    public static boolean isKeepOldStories(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        return prefs.getBoolean(PrefConstants.KEEP_OLD_STORIES, false);
    }

    public static void applyThemePreference(Activity activity) {
        SharedPreferences prefs = activity.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        String theme = prefs.getString(PrefConstants.THEME, "light");
        if (theme.equals("light")) {
            activity.setTheme(R.style.NewsBlurTheme);
        } else {
            activity.setTheme(R.style.NewsBlurDarkTheme);
        }
    }

    public static boolean isLightThemeSelected(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
        String theme = prefs.getString(PrefConstants.THEME, "light");
        return theme.equals("light");
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
}
