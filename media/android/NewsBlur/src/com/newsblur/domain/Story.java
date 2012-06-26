package com.newsblur.domain;

import android.content.ContentValues;

import com.newsblur.database.DatabaseConstants;

public class Story {
	
	public final ContentValues values = new ContentValues();
	
	public void setId(final String id) {
		values.put(DatabaseConstants.STORY_ID, id);
	}
	
	public void setTitle(final String title) {
		values.put(DatabaseConstants.STORY_TITLE, title);
	}
	
	public void setDate(final String date) {
		values.put(DatabaseConstants.STORY_DATE, date);
	}
	
	public void setContent(final String content) {
		values.put(DatabaseConstants.STORY_CONTENT, content);
	}
	
	public void setPermalink(final String permalink) {
		values.put(DatabaseConstants.STORY_PERMALINK, permalink);
	}

	public void setAuthors(final String authors) {
		values.put(DatabaseConstants.STORY_AUTHORS, authors);
	}
	
	public void setIntelligenceAuthors(final String authors) {
		values.put(DatabaseConstants.STORY_INTELLIGENCE_AUTHORS, authors);
	}
	
	public void setIntelligenceTags(final String tags) {
		values.put(DatabaseConstants.STORY_INTELLIGENCE_TAGS, tags);
	}
	
	public void setIntelligenceFeed(final String feed) {
		values.put(DatabaseConstants.STORY_INTELLIGENCE_FEED, feed);
	}
	
	public void setIntelligenceTitle(final String title) {
		values.put(DatabaseConstants.STORY_INTELLIGENCE_TITLE, title);
	}
	
	public void setRead(final String read) {
		values.put(DatabaseConstants.STORY_READ, read);
	}
	
	public void setFeedId(final String feedId) {
		values.put(DatabaseConstants.STORY_FEED_ID, feedId);
	}
	
}
