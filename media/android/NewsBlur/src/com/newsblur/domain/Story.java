package com.newsblur.domain;

import java.io.Serializable;
import java.util.Date;

import android.content.ContentValues;
import android.database.Cursor;
import android.text.TextUtils;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

public class Story implements Serializable {

	private static final long serialVersionUID = 7629596752129163308L;

	public String id;
	
	@SerializedName("story_permalink")
	public String permalink;

	@SerializedName("share_count")
	public String shareCount;
	
	@SerializedName("share_user_ids")
	public String[] sharedUserIds;

	@SerializedName("shared_by_friends")
	public String[] friendUserIds = new String[]{};
	
	@SerializedName("shared_by_public")
	public String[] publicUserIds = new String[]{};
	
	@SerializedName("comment_count")
	public int commentCount;

	@SerializedName("read_status")
	public int read;

	@SerializedName("story_tags")
	public String[] tags;

	@SerializedName("social_user_id")
	public String socialUserId;

	@SerializedName("source_user_id")
	public String sourceUserId;
	
	@SerializedName("story_title")
	public String title;

	@SerializedName("story_date")
	public Date date;
	
	@SerializedName("shared_date")
	public Date sharedDate;

	@SerializedName("story_content")
	public String content;

	@SerializedName("story_authors")
	public String authors;

	@SerializedName("story_feed_id")
	public String feedId;

	@SerializedName("public_comments")
	public Comment[] publicComments;
	
	@SerializedName("friend_comments")
	public Comment[] friendsComments;

	@SerializedName("intelligence")
	public Intelligence intelligence = new Intelligence();

	@SerializedName("short_parsed_date")
	public String shortDate;
	
	@SerializedName("long_parsed_date")
	public String longDate;
	
	public ContentValues getValues() {
		final ContentValues values = new ContentValues();
		values.put(DatabaseConstants.STORY_ID, id);
		values.put(DatabaseConstants.STORY_TITLE, title.replace("\n", " ").replace("\r", " "));
		values.put(DatabaseConstants.STORY_DATE, date.getTime());
		values.put(DatabaseConstants.STORY_SHARED_DATE, sharedDate != null ? sharedDate.getTime() : new Date().getTime());
		values.put(DatabaseConstants.STORY_SHORTDATE, shortDate);
		values.put(DatabaseConstants.STORY_LONGDATE, longDate);
		values.put(DatabaseConstants.STORY_CONTENT, content);
		values.put(DatabaseConstants.STORY_PERMALINK, permalink);
		values.put(DatabaseConstants.STORY_COMMENT_COUNT, commentCount);
		values.put(DatabaseConstants.STORY_SHARE_COUNT, shareCount);
		values.put(DatabaseConstants.STORY_AUTHORS, authors);
		values.put(DatabaseConstants.STORY_SOCIAL_USER_ID, socialUserId);
		values.put(DatabaseConstants.STORY_SOURCE_USER_ID, sourceUserId);
		values.put(DatabaseConstants.STORY_SHARED_USER_IDS, TextUtils.join(",", sharedUserIds));
		values.put(DatabaseConstants.STORY_FRIEND_USER_IDS, TextUtils.join(",", friendUserIds));
		values.put(DatabaseConstants.STORY_PUBLIC_USER_IDS, TextUtils.join(",", publicUserIds));
		values.put(DatabaseConstants.STORY_INTELLIGENCE_AUTHORS, intelligence.intelligenceAuthors);
		values.put(DatabaseConstants.STORY_INTELLIGENCE_FEED, intelligence.intelligenceFeed);
		values.put(DatabaseConstants.STORY_INTELLIGENCE_TAGS, intelligence.intelligenceTags);
		values.put(DatabaseConstants.STORY_INTELLIGENCE_TITLE, intelligence.intelligenceTitle);
		values.put(DatabaseConstants.STORY_TAGS, TextUtils.join(",", tags));
		values.put(DatabaseConstants.STORY_READ, read);
		values.put(DatabaseConstants.STORY_FEED_ID, feedId);
		return values;
	}
	
	public static Story fromCursor(final Cursor cursor) {
		Story story = new Story();
		story.authors = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_AUTHORS));
		story.content = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_CONTENT));
		story.title = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_TITLE));
		story.date = new Date(cursor.getLong(cursor.getColumnIndex(DatabaseConstants.STORY_DATE)));
		story.sharedDate = new Date(cursor.getLong(cursor.getColumnIndex(DatabaseConstants.STORY_DATE)));
		story.shortDate = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_SHORTDATE));
		story.longDate = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_LONGDATE));
		story.shareCount = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_SHARE_COUNT));
		story.commentCount = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_COMMENT_COUNT));
		story.socialUserId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_SOCIAL_USER_ID));
		story.sourceUserId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_SOURCE_USER_ID));
		story.permalink = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_PERMALINK));
		story.sharedUserIds = TextUtils.split(cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_SHARED_USER_IDS)), ",");
		story.friendUserIds = TextUtils.split(cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_FRIEND_USER_IDS)), ",");
		story.publicUserIds = TextUtils.split(cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_PUBLIC_USER_IDS)), ",");
		story.intelligence.intelligenceAuthors = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_AUTHORS));
		story.intelligence.intelligenceFeed = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_FEED));
		story.intelligence.intelligenceTags = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_TAGS));
		story.intelligence.intelligenceTitle = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_TITLE));
		story.read = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_READ));
		story.tags = TextUtils.split(cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_TAGS)), ",");
		story.feedId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_FEED_ID));
		story.id = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_ID));
		return story;
	}
	
	public class Intelligence implements Serializable {
		private static final long serialVersionUID = -1314486209455376730L;

		@SerializedName("feed")
		public int intelligenceFeed = 0;
		
		@SerializedName("author")
		public int intelligenceAuthors = 0;
		
		@SerializedName("tags")
		public int intelligenceTags = 0;
		
		@SerializedName("title")
		public int intelligenceTitle = 0;
	}
	
	public int getIntelligenceTotal() {
		return (intelligence.intelligenceAuthors + intelligence.intelligenceFeed + intelligence.intelligenceTags + intelligence.intelligenceTitle);
	}
}
