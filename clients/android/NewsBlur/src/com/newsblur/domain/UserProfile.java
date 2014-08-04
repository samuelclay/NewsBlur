package com.newsblur.domain;

import android.content.ContentValues;
import android.database.Cursor;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

// A UserDetails object is distinct from a UserProfile in that it contains more data and is
// only requested on its own. A UserProfile is include with feed/story requests.
public class UserProfile {
	
	@SerializedName("photo_url")
	public String photoUrl;
	
	@SerializedName("user_id")
	public String userId;

    public String username;
    public String location;

	public static UserProfile fromCursor(final Cursor c) {
        if (c.getCount() < 1) return null;

		if (c.isBeforeFirst()) {
			c.moveToFirst();
		}
			
		UserProfile profile = new UserProfile();
		profile.userId = c.getString(c.getColumnIndex(DatabaseConstants.USER_USERID));
		profile.photoUrl = c.getString(c.getColumnIndex(DatabaseConstants.USER_PHOTO_URL));
        profile.username = c.getString(c.getColumnIndex(DatabaseConstants.USER_USERNAME));
        profile.location = c.getString(c.getColumnIndex(DatabaseConstants.USER_LOCATION));
		
		return profile;
	}
	
	public ContentValues getValues() {
		final ContentValues values = new ContentValues();
		values.put(DatabaseConstants.USER_PHOTO_URL, photoUrl);
		values.put(DatabaseConstants.USER_USERID, userId);
        values.put(DatabaseConstants.USER_USERNAME, username);
        values.put(DatabaseConstants.USER_LOCATION, location);
		return values;
	}
	
}
