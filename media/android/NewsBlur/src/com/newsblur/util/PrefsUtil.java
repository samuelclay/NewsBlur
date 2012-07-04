package com.newsblur.util;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;

import com.newsblur.activity.PrefConstants;
import com.newsblur.domain.UserProfile;

public class PrefsUtil {
	
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
		edit.putString(PrefConstants.USER_ID, profile.id);
		edit.putString(PrefConstants.USER_LOCATION, profile.location);
		edit.putString(PrefConstants.USER_PHOTO_SERVICE, profile.photoService);
		edit.putString(PrefConstants.USER_PHOTO_URL, profile.photoUrl);
		edit.putString(PrefConstants.USER_POPULAR_PUBLISHERS, profile.popularPublishers);
		edit.putInt(PrefConstants.USER_SHARED_STORIES_COUNT, profile.sharedStoriesCount);
		edit.putInt(PrefConstants.USER_STORIES_LAST_MONTH, profile.storiesLastMonth);
		edit.putInt(PrefConstants.USER_STORIES_LAST_MONTH, profile.storiesLastMonth);
		edit.putInt(PrefConstants.USER_SUBSCRIBER_COUNT, profile.subscriptionCount);
		edit.putString(PrefConstants.USER_USERNAME, profile.username);
		edit.putString(PrefConstants.USER_WEBSITE, profile.website);
		edit.commit();
		
	}

}
