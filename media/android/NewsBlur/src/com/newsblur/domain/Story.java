package com.newsblur.domain;

import android.content.ContentValues;
import android.text.TextUtils;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

public class Story {

	public String id;
	public String permalink;

	@SerializedName("share_count")
	public Integer shareCount;

	@SerializedName("comment_count")
	public Integer commentCount;

	@SerializedName("read_status")
	public Boolean read;

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

}
