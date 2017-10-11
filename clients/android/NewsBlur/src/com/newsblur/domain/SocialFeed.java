package com.newsblur.domain;

import android.content.ContentValues;
import android.database.Cursor;
import android.text.TextUtils;

import java.io.Serializable;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

public class SocialFeed implements Serializable {

    private static final long serialVersionUID = 0L;
	
	public String username;
	
	@SerializedName("feed_title")
	public String feedTitle;
	
	@SerializedName("user_id")
	public String userId;
	
	@SerializedName("nt")
	public int neutralCount;
	
	@SerializedName("ng")
	public int negativeCount;
	
	@SerializedName("ps")
	public int positiveCount;
	
	@SerializedName("photo_url")
	public String photoUrl;
	
	public ContentValues getValues() {
		ContentValues values = new ContentValues();
		values.put(DatabaseConstants.SOCIAL_FEED_ID, userId);
		values.put(DatabaseConstants.SOCIAL_FEED_TITLE, feedTitle);
		values.put(DatabaseConstants.SOCIAL_FEED_USERNAME, username);
		values.put(DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT, neutralCount);
		values.put(DatabaseConstants.SOCIAL_FEED_NEGATIVE_COUNT, negativeCount);
		values.put(DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT, positiveCount);
		values.put(DatabaseConstants.SOCIAL_FEED_ICON, photoUrl);
		return values;
	}
	
	public static SocialFeed fromCursor(final Cursor cursor) {
		if (cursor.isBeforeFirst()) {
			cursor.moveToFirst();
		}
		SocialFeed socialFeed = new SocialFeed();
		socialFeed.userId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_ID));
		socialFeed.username = cursor.getString(cursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_USERNAME));
		socialFeed.feedTitle = cursor.getString(cursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_TITLE));
		socialFeed.photoUrl = cursor.getString(cursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_ICON));
		socialFeed.negativeCount = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_NEGATIVE_COUNT));
		socialFeed.positiveCount = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_POSITIVE_COUNT));
		socialFeed.neutralCount = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.SOCIAL_FEED_NEUTRAL_COUNT));
		return socialFeed;
	}
	
	@Override
	public boolean equals(Object o) {
        if (! (o instanceof SocialFeed)) return false;
		SocialFeed otherFeed = (SocialFeed) o;
		return (TextUtils.equals(userId, otherFeed.userId));
	}

    @Override
    public int hashCode() {
        return userId.hashCode();
    }
	
}
