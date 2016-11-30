package com.newsblur.domain;

import java.io.Serializable;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import android.content.ContentValues;
import android.database.Cursor;
import android.text.TextUtils;

import com.google.gson.annotations.SerializedName;

import com.newsblur.database.DatabaseConstants;
import com.newsblur.util.StateFilter;

public class Story implements Serializable {

	private static final long serialVersionUID = 7629596752129163308L;

	public String id;

	@SerializedName("story_permalink")
	public String permalink;

	@SerializedName("share_user_ids")
	public String[] sharedUserIds;

	@SerializedName("shared_by_friends")
	public String[] friendUserIds = new String[]{};

	@SerializedName("read_status")
	public boolean read;

    @SerializedName("starred")
    public boolean starred;

    @SerializedName("starred_timestamp")
    public long starredTimestamp;

	@SerializedName("story_tags")
	public String[] tags;

    @SerializedName("user_tags")
    public String[] userTags = new String[]{};

	@SerializedName("social_user_id")
	public String socialUserId;

	@SerializedName("source_user_id")
	public String sourceUserId;

	@SerializedName("story_title")
	public String title;

	@SerializedName("story_timestamp")
	public long timestamp;

    // NOTE: this is parsed and saved to the DB, but is *not* generally un-thawed when stories are fetched back from the DB, due to size
    @SerializedName("story_content")
    public String content;

    // this isn't actually a serialized field, but created client-size in StoryTypeAdapter
    public String shortContent;

	@SerializedName("story_authors")
	public String authors;

	@SerializedName("story_feed_id")
	public String feedId;

	@SerializedName("public_comments")
	public Comment[] publicComments;

	@SerializedName("friend_comments")
	public Comment[] friendsComments;

	// these are pseudo-comments that allow replying to empty shares
    @SerializedName("friend_shares")
	public Comment[] friendsShares;

	@SerializedName("intelligence")
	public Intelligence intelligence = new Intelligence();

    @SerializedName("story_hash")
    public String storyHash;

    // NOTE: this is parsed and saved to the DB, but is *not* generally un-thawed when stories are fetched back from the DB
    @SerializedName("image_urls")
    public String[] imageUrls;

    // not yet vended by the API, but tracked locally and fudged (see SyncService) for remote stories
    public long lastReadTimestamp = 0L;

    // non-API and only set once when story is pushed to DB so it can be selected upon
    public String searchHit = "";

    // non-API, though it probably could/should be. populated on first story ingest if thumbnails are turned on
    public String thumbnailUrl;
 
	public ContentValues getValues() {
		final ContentValues values = new ContentValues();
		values.put(DatabaseConstants.STORY_ID, id);
		values.put(DatabaseConstants.STORY_TITLE, title.replace("\n", " ").replace("\r", " "));
		values.put(DatabaseConstants.STORY_TIMESTAMP, timestamp);
        values.put(DatabaseConstants.STORY_CONTENT, content);
        values.put(DatabaseConstants.STORY_SHORT_CONTENT, shortContent);
		values.put(DatabaseConstants.STORY_PERMALINK, permalink);
		values.put(DatabaseConstants.STORY_AUTHORS, authors);
		values.put(DatabaseConstants.STORY_SOCIAL_USER_ID, socialUserId);
		values.put(DatabaseConstants.STORY_SOURCE_USER_ID, sourceUserId);
		values.put(DatabaseConstants.STORY_SHARED_USER_IDS, TextUtils.join(",", sharedUserIds));
		values.put(DatabaseConstants.STORY_FRIEND_USER_IDS, TextUtils.join(",", friendUserIds));
		values.put(DatabaseConstants.STORY_INTELLIGENCE_AUTHORS, intelligence.intelligenceAuthors);
		values.put(DatabaseConstants.STORY_INTELLIGENCE_FEED, intelligence.intelligenceFeed);
		values.put(DatabaseConstants.STORY_INTELLIGENCE_TAGS, intelligence.intelligenceTags);
		values.put(DatabaseConstants.STORY_INTELLIGENCE_TITLE, intelligence.intelligenceTitle);
        values.put(DatabaseConstants.STORY_INTELLIGENCE_TOTAL, intelligence.calcTotalIntel());
		values.put(DatabaseConstants.STORY_TAGS, TextUtils.join(",", tags));
		values.put(DatabaseConstants.STORY_USER_TAGS, TextUtils.join(",", userTags));
		values.put(DatabaseConstants.STORY_READ, read);
		values.put(DatabaseConstants.STORY_STARRED, starred);
		values.put(DatabaseConstants.STORY_STARRED_DATE, starredTimestamp);
		values.put(DatabaseConstants.STORY_FEED_ID, feedId);
        values.put(DatabaseConstants.STORY_HASH, storyHash);
        values.put(DatabaseConstants.STORY_IMAGE_URLS, TextUtils.join(",", imageUrls));
        values.put(DatabaseConstants.STORY_LAST_READ_DATE, lastReadTimestamp);
		values.put(DatabaseConstants.STORY_SEARCH_HIT, searchHit);
        values.put(DatabaseConstants.STORY_THUMBNAIL_URL, thumbnailUrl);
		return values;
	}

	public static Story fromCursor(final Cursor cursor) {
		if (cursor.isBeforeFirst()) {
			cursor.moveToFirst();
		}
		Story story = new Story();
		story.authors = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_AUTHORS));
		story.shortContent = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_SHORT_CONTENT));
		story.title = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_TITLE));
		story.timestamp = cursor.getLong(cursor.getColumnIndex(DatabaseConstants.STORY_TIMESTAMP));
		story.socialUserId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_SOCIAL_USER_ID));
		story.sourceUserId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_SOURCE_USER_ID));
		story.permalink = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_PERMALINK));
		story.sharedUserIds = TextUtils.split(cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_SHARED_USER_IDS)), ",");
		story.friendUserIds = TextUtils.split(cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_FRIEND_USER_IDS)), ",");
		story.intelligence.intelligenceAuthors = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_AUTHORS));
		story.intelligence.intelligenceFeed = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_FEED));
		story.intelligence.intelligenceTags = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_TAGS));
		story.intelligence.intelligenceTitle = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_INTELLIGENCE_TITLE));
		story.read = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_READ)) > 0;
		story.starred = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.STORY_STARRED)) > 0;
		story.starredTimestamp = cursor.getLong(cursor.getColumnIndex(DatabaseConstants.STORY_STARRED_DATE));
		story.tags = TextUtils.split(cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_TAGS)), ",");
		story.userTags = TextUtils.split(cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_USER_TAGS)), ",");
		story.feedId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_FEED_ID));
		story.id = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_ID));
        story.storyHash = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_HASH));
        story.lastReadTimestamp = cursor.getLong(cursor.getColumnIndex(DatabaseConstants.STORY_LAST_READ_DATE));
		story.thumbnailUrl = cursor.getString(cursor.getColumnIndex(DatabaseConstants.STORY_THUMBNAIL_URL));
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

        public int calcTotalIntel() {
            int max = 0;
            max = Math.max(max, intelligenceAuthors);
            max = Math.max(max, intelligenceTags);
            max = Math.max(max, intelligenceTitle);
            if (max > 0) return max;

            int min = 0;
            min = Math.min(min, intelligenceAuthors);
            min = Math.min(min, intelligenceTags);
            min = Math.min(min, intelligenceTitle);
            if (min < 0) return min;

            return intelligenceFeed;
        }
	}

    public boolean isStoryVisibileInState(StateFilter state) {
        int score = intelligence.calcTotalIntel();
        switch (state) {
        case ALL:
            return true;
        case SOME:
            return (score >= 0);
        case NEUT:
            return (score == 0);
        case BEST:
            return (score > 0);
        case NEG:
            return (score < 0);
        case SAVED:
            return (starred == true);
        default:
            return true;
        }
    }

    /**
     * Custom equality based on storyID/feedID equality so that a Set can de-duplicate story objects.
     */
    @Override
    public boolean equals(Object o) {
        if (o == null) return false;
        if (!(o instanceof Story)) return false;
        Story s = (Story) o;
        return ( (this.id == null ? s.id == null : this.id.equals(s.id)) && (this.feedId == null ? s.feedId == null : this.feedId.equals(s.feedId)) );
    }

    /**
     * Per the contract of Object, since we redefined equals(), we have to redefine hashCode().
     */
    @Override
    public int hashCode() {
        int result = 17;
        if (this.id == null) { result = 37*result; } else { result = 37*result + this.id.hashCode();}
        if (this.feedId == null) { result = 37*result; } else { result = 37*result + this.feedId.hashCode();}
        return result;
    }

    private static final Pattern ytSniff1 = Pattern.compile("youtube\\.com\\/embed\\/([A-Za-z0-9_-]+)", Pattern.CASE_INSENSITIVE);
    private static final Pattern ytSniff2 = Pattern.compile("youtube\\.com\\/v\\/([A-Za-z0-9_-]+)", Pattern.CASE_INSENSITIVE);
    private static final Pattern ytSniff3 = Pattern.compile("ytimg\\.com\\/vi\\/([A-Za-z0-9_-]+)", Pattern.CASE_INSENSITIVE);
    private static final Pattern ytSniff4 = Pattern.compile("youtube\\.com\\/watch\\?v=([A-Za-z0-9_-]+)", Pattern.CASE_INSENSITIVE);
    private static final String YT_THUMB_PRE = "http://img.youtube.com/vi/";
    private static final String YT_THUMB_POST = "/0.jpg";

    public static String guessStoryThumbnailURL(Story story) {
        String content = story.content;
        
        String ytUrl = null;
        if (ytUrl == null) {
            Matcher m = ytSniff1.matcher(content);
            if (m.find()) ytUrl = m.group(1);
        }
        if (ytUrl == null) {
            Matcher m = ytSniff2.matcher(content);
            if (m.find()) ytUrl = m.group(1);
        }
        if (ytUrl == null) {
            Matcher m = ytSniff3.matcher(content);
            if (m.find()) ytUrl = m.group(1);
        }
        if (ytUrl == null) {
            Matcher m = ytSniff4.matcher(content);
            if (m.find()) ytUrl = m.group(1);
        }
        if (ytUrl != null) {
            return YT_THUMB_PRE + ytUrl + YT_THUMB_POST;
        }

        if ((story.imageUrls != null) && (story.imageUrls.length > 0)) {
            return story.imageUrls[0];
        }

        return null;
    }

}
