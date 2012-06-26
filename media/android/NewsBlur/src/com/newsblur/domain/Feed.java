package com.newsblur.domain;

import com.newsblur.database.DatabaseConstants;

import android.content.ContentValues;

public class Feed {
	
	public final ContentValues values = new ContentValues();
	
	public void setId(final String feedId) {
		values.put(DatabaseConstants.FEED_ID, feedId);
	}
	
	public void setActive(final String active) {
		values.put(DatabaseConstants.FEED_ACTIVE, active);
	}
	
	public void setAddress(final String address) {
		values.put(DatabaseConstants.FEED_ADDRESS, address);
	}
	
	public void setFaviconColour(final String faviconColour) {
		values.put(DatabaseConstants.FEED_FAVICON_COLOUR, faviconColour);
	}
	
	public void setFaviconFade(final String faviconFade) {
		values.put(DatabaseConstants.FEED_FAVICON_FADE, faviconFade);
	}
	
	public void setLink(final String feedLink) {
		values.put(DatabaseConstants.FEED_LINK, feedLink);	
	}
	 
	public void setSubscribers(final String feedSubscribers) {
		values.put(DatabaseConstants.FEED_SUBSCRIBERS, feedSubscribers);
	}
	
	public void setTitle(final String title) {
		values.put(DatabaseConstants.FEED_TITLE, title);
	}
	
	public void setLastUpdated(final String lastUpdated) {
		values.put(DatabaseConstants.FEED_UPDATED_SECONDS, lastUpdated);
	}

}
