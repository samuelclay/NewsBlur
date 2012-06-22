package com.newsblur.domain;

import com.newsblur.database.Constants;

import android.content.ContentValues;

public class Feed {
	
	public final ContentValues values = new ContentValues();
	
	public void setId(final String feedId) {
		values.put(Constants.FEED_ID, feedId);
	}
	
	public void setActive(final String active) {
		values.put(Constants.FEED_ACTIVE, active);
	}
	
	public void setAddress(final String address) {
		values.put(Constants.FEED_ADDRESS, address);
	}
	
	public void setFaviconColour(final String faviconColour) {
		values.put(Constants.FEED_FAVICON_COLOUR, faviconColour);
	}
	
	public void setFaviconFade(final String faviconFade) {
		values.put(Constants.FEED_FAVICON_FADE, faviconFade);
	}
	
	public void setLink(final String feedLink) {
		values.put(Constants.FEED_LINK, feedLink);	
	}
	 
	public void setSubscribers(final String feedSubscribers) {
		values.put(Constants.FEED_SUBSCRIBERS, feedSubscribers);
	}
	
	public void setTitle(final String title) {
		values.put(Constants.FEED_TITLE, title);
	}
	
	public void setLastUpdated(final String lastUpdated) {
		values.put(Constants.FEED_UPDATED_SECONDS, lastUpdated);
	}

}
