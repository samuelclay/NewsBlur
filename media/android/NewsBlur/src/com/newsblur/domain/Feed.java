package com.newsblur.domain;

import android.content.ContentValues;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

public class Feed {	
	
	@SerializedName("id")
	public String feedId;
	
	@SerializedName("active")
	public boolean active;
	
	@SerializedName("feed_address")
	public String address;
	
	@SerializedName("favicon_color")
	public String faviconColour;
	
	@SerializedName("favicon_fade")
	public String faviconFade;
	
	@SerializedName("feed_link")
	public String feedLink;
	
	@SerializedName("num_subscribers")
	public String subscribers;
	
	@SerializedName("feed_title")
	public String title;
	
	@SerializedName("updated_seconds_ago")
	public String lastUpdated;
	
	public ContentValues getValues() {
		ContentValues values = new ContentValues();
		values.put(DatabaseConstants.FEED_ID, feedId);
		values.put(DatabaseConstants.FEED_ACTIVE, active);
		values.put(DatabaseConstants.FEED_ADDRESS, address);
		values.put(DatabaseConstants.FEED_FAVICON_COLOUR, faviconColour);
		values.put(DatabaseConstants.FEED_FAVICON_FADE, faviconFade);
		values.put(DatabaseConstants.FEED_LINK, feedLink);
		values.put(DatabaseConstants.FEED_SUBSCRIBERS, subscribers);
		values.put(DatabaseConstants.FEED_TITLE, title);
		values.put(DatabaseConstants.FEED_UPDATED_SECONDS, lastUpdated);
		return values;
	}
	
}
