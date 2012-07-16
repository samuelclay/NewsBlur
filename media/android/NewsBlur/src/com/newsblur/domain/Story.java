package com.newsblur.domain;

import android.content.ContentValues;
import android.database.Cursor;
import android.text.TextUtils;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

public class Story {

	public String id;
	
	@SerializedName("story_permalink")
	public String permalink;

	@SerializedName("share_count")
	public Integer shareCount;

	@SerializedName("comment_count")
	public Integer commentCount;

	@SerializedName("read_status")
	public int read;

	@SerializedName("story_tags")
	public String[] tags;

	@SerializedName("source_user_id")
	public Integer sourceUserId;

	@SerializedName("story_title")
	public String title;

	@SerializedName("short_parsed_date")
	public String date;

	@SerializedName("story_content")
	public String content;

	@SerializedName("story_authors")
	public String authors;

	@SerializedName("story_feed_id")
	public String feedId;

	@SerializedName("intelligence_feed")
	public String intelligenceFeed;
	
	@SerializedName("intelligence_authors")
	public String intelligenceAuthors;

	@SerializedName("intelligence_title")
	public String intelligenceTitle;

	public ContentValues getValues() {
		final ContentValues values = new ContentValues();
		values.put(DatabaseConstants.STORY_ID, id);
		values.put(DatabaseConstants.STORY_TITLE, title);
		values.put(DatabaseConstants.STORY_DATE, date);
		values.put(DatabaseConstants.STORY_CONTENT, content);
		values.put(DatabaseConstants.STORY_PERMALINK, permalink);
		values.put(DatabaseConstants.STORY_AUTHORS, authors);
		values.put(DatabaseConstants.STORY_INTELLIGENCE_AUTHORS, intelligenceAuthors);
		values.put(DatabaseConstants.STORY_INTELLIGENCE_TAGS, TextUtils.join(",", tags));
		values.put(DatabaseConstants.STORY_INTELLIGENCE_FEED, intelligenceFeed);
		values.put(DatabaseConstants.STORY_INTELLIGENCE_TITLE, intelligenceTitle);
		values.put(DatabaseConstants.STORY_READ, read);
		values.put(DatabaseConstants.STORY_FEED_ID, feedId);
		return values;
	}
	
	public static Story fromCursor(final Cursor cursor) {
		Story story = new Story();
		story.authors = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_AUTHORS));
		story.content = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_CONTENT));
		story.title = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_TITLE));
		story.date = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_DATE));
		story.permalink = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_PERMALINK));
		story.intelligenceAuthors = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_AUTHORS));
		story.tags = TextUtils.split(cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_TAGS)), ",");
		story.intelligenceFeed = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_FEED));
		story.read = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_READ));
		story.feedId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_FEED_ID));
		story.id = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_ID));
		return story;
	}

}
