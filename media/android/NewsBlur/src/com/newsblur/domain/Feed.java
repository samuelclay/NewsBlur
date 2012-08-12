package com.newsblur.domain;

import android.content.ContentValues;
import android.database.Cursor;

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

	@SerializedName("favicon_border")
	public String faviconBorder;

	@SerializedName("favicon")
	public String favicon;
	
	@SerializedName("favicon_url")
	public String faviconUrl;

	@SerializedName("nt")
	public int neutralCount;

	@SerializedName("ng")
	public int negativeCount;

	@SerializedName("ps")
	public int positiveCount;

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
		values.put(DatabaseConstants.FEED_FAVICON_COLOUR, "#" + faviconColour);
		values.put(DatabaseConstants.FEED_FAVICON_BORDER, "#" + faviconBorder);
		values.put(DatabaseConstants.FEED_POSITIVE_COUNT, positiveCount);
		values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, neutralCount);
		values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, negativeCount);
		values.put(DatabaseConstants.FEED_FAVICON_FADE, "#" + faviconFade);
		values.put(DatabaseConstants.FEED_FAVICON, favicon);
		values.put(DatabaseConstants.FEED_FAVICON_URL, faviconUrl);
		values.put(DatabaseConstants.FEED_LINK, feedLink);
		values.put(DatabaseConstants.FEED_SUBSCRIBERS, subscribers);
		values.put(DatabaseConstants.FEED_TITLE, title);
		values.put(DatabaseConstants.FEED_UPDATED_SECONDS, lastUpdated);
		return values;
	}

	public static Feed fromCursor(Cursor childCursor) {
		Feed feed = new Feed();
		feed.active = Boolean.parseBoolean(childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_ACTIVE)));
		feed.address = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_ADDRESS));
		feed.favicon = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_FAVICON));
		feed.faviconColour = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOUR));
		feed.faviconFade = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_FADE));
		feed.faviconBorder = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_BORDER));
		feed.faviconUrl = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_URL));
		feed.feedId = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_ID));
		feed.feedLink = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_LINK));
		feed.lastUpdated = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_UPDATED_SECONDS));
		feed.negativeCount = childCursor.getInt(childCursor.getColumnIndex(DatabaseConstants.FEED_NEGATIVE_COUNT));
		feed.neutralCount = childCursor.getInt(childCursor.getColumnIndex(DatabaseConstants.FEED_NEUTRAL_COUNT));
		feed.positiveCount = childCursor.getInt(childCursor.getColumnIndex(DatabaseConstants.FEED_POSITIVE_COUNT));
		feed.subscribers = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_SUBSCRIBERS));
		feed.title = childCursor.getString(childCursor.getColumnIndex(DatabaseConstants.FEED_TITLE));
		childCursor.close();
		return feed;
	}

}
