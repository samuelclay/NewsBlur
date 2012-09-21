package com.newsblur.util;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.net.URLConnection;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.graphics.Bitmap;
import android.graphics.Bitmap.CompressFormat;
import android.graphics.BitmapFactory;

import com.newsblur.domain.UserProfile;

public class PrefsUtils {

	public static void saveCookie(final Context context, final String cookie) {
		final SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		final Editor edit = preferences.edit();
		edit.putString(PrefConstants.PREF_COOKIE, cookie);
		edit.commit();
	}

	public static void saveUserDetails(final Context context, final UserProfile profile) {
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

	public static UserProfile getUserDetails(final Context context) {
		UserProfile user = new UserProfile();

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


}
