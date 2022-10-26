package com.newsblur.domain;

import android.content.ContentValues;
import android.database.Cursor;
import android.text.TextUtils;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.util.FeedListOrder;
import com.newsblur.util.FeedUtils;

public class Feed implements Comparable<Feed>, Serializable {	

    private static final long serialVersionUID = 0L;

	@SerializedName("id")
	public String feedId;

	@SerializedName("active")
	public boolean active;
	
	@SerializedName("feed_address")
	public String address;

	@SerializedName("favicon_color")
	public String faviconColor;

	@SerializedName("favicon_border")
	public String faviconBorder;

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

    @SerializedName("favicon_text_color")
    public String faviconText;

	@SerializedName("feed_link")
	public String feedLink;

	@SerializedName("num_subscribers")
	public String subscribers;

	@SerializedName("feed_opens")
    public int feedOpens;

	@SerializedName("last_story_date")
    public String lastStoryDate;

	@SerializedName("average_stories_per_month")
    public int storiesPerMonth;

	@SerializedName("feed_title")
	public String title;

	@SerializedName("updated_seconds_ago")
	public int lastUpdated;

    @SerializedName("notification_types")
    public List<String> notificationTypes;

    @SerializedName("notification_filter")
    public String notificationFilter;

    // not vended by API, but used locally for UI
    public boolean fetchPending;

	public ContentValues getValues() {
		ContentValues values = new ContentValues();
		values.put(DatabaseConstants.FEED_ID, feedId);
		values.put(DatabaseConstants.FEED_ACTIVE, active);
		values.put(DatabaseConstants.FEED_ADDRESS, address);
		values.put(DatabaseConstants.FEED_FAVICON_COLOR, faviconColor);
		values.put(DatabaseConstants.FEED_FAVICON_BORDER, faviconBorder);
		values.put(DatabaseConstants.FEED_POSITIVE_COUNT, positiveCount);
		values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, neutralCount);
		values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, negativeCount);
        values.put(DatabaseConstants.FEED_FAVICON_FADE, faviconFade);
        values.put(DatabaseConstants.FEED_FAVICON_TEXT, faviconText);
		values.put(DatabaseConstants.FEED_FAVICON_URL, faviconUrl);
		values.put(DatabaseConstants.FEED_LINK, feedLink);
		values.put(DatabaseConstants.FEED_SUBSCRIBERS, subscribers);
		values.put(DatabaseConstants.FEED_OPENS, feedOpens);
		values.put(DatabaseConstants.FEED_LAST_STORY_DATE, lastStoryDate);
		values.put(DatabaseConstants.FEED_AVERAGE_STORIES_PER_MONTH, storiesPerMonth);
		values.put(DatabaseConstants.FEED_TITLE, title);
		values.put(DatabaseConstants.FEED_UPDATED_SECONDS, lastUpdated);
        values.put(DatabaseConstants.FEED_NOTIFICATION_TYPES, DatabaseConstants.flattenStringList(notificationTypes));
        values.put(DatabaseConstants.FEED_NOTIFICATION_FILTER, notificationFilter);
        values.put(DatabaseConstants.FEED_FETCH_PENDING, fetchPending);
		return values;
	}

	public static Feed fromCursor(Cursor cursor) {
		if (cursor.isBeforeFirst()) {
			cursor.moveToFirst();
		}
		Feed feed = new Feed();
		feed.active = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_ACTIVE)).equals("1");
		feed.address = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_ADDRESS));
		feed.faviconColor = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_COLOR));
        feed.faviconFade = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_FADE));
        feed.faviconBorder = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_BORDER));
        feed.faviconText = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_TEXT));
		feed.faviconUrl = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FAVICON_URL));
		feed.feedId = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_ID));
		feed.feedLink = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_LINK));
		feed.negativeCount = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.FEED_NEGATIVE_COUNT));
		feed.neutralCount = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.FEED_NEUTRAL_COUNT));
		feed.positiveCount = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.FEED_POSITIVE_COUNT));
		feed.subscribers = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_SUBSCRIBERS));
		feed.feedOpens = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.FEED_OPENS));
		feed.storiesPerMonth = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.FEED_AVERAGE_STORIES_PER_MONTH));
		feed.lastStoryDate = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_LAST_STORY_DATE));
		feed.title = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_TITLE));
        feed.lastUpdated = cursor.getInt(cursor.getColumnIndex(DatabaseConstants.FEED_UPDATED_SECONDS));
        feed.notificationTypes = DatabaseConstants.unflattenStringList(cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_NOTIFICATION_TYPES)));
        feed.notificationFilter = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_NOTIFICATION_FILTER));
        feed.fetchPending = cursor.getString(cursor.getColumnIndex(DatabaseConstants.FEED_FETCH_PENDING)).equals("1");
		return feed;
	}

    /**
     * Creates an returns the implicit zero-id feed that NewsBlur uses for feedless stories.
     */
    public static Feed getZeroFeed() {
        Feed feed = new Feed();
        feed.active = false;
        feed.faviconUrl = "https://www.newsblur.com/rss_feeds/icon/0";
        feed.feedId = "0";
        feed.negativeCount = 0;
        feed.neutralCount = 0;
        feed.positiveCount = 0;
        return feed;
    }
	
	@Override
	public boolean equals(Object o) {
        if (! (o instanceof Feed)) return false;
		Feed otherFeed = (Feed) o;
		return (FeedUtils.textUtilsEquals(feedId, otherFeed.feedId));
	}

    @Override
    public int hashCode() {
        return feedId.hashCode();
    }

    public int compareTo(Feed f) {
        return title.compareToIgnoreCase(f.title);
    }

    public static Comparator<Feed> getFeedListOrderComparator(FeedListOrder feedListOrder) {
        return (o1, o2) -> {
            if (feedListOrder == FeedListOrder.MOST_USED_AT_TOP) {
                return Integer.compare(o2.feedOpens, o1.feedOpens);
            } else {
                return o1.title.compareToIgnoreCase(o2.title);
            }
        };
    }

    public static String NOTIFY_FILTER_UNREAD = "unread";
    public static String NOTIFY_FILTER_FOCUS = "focus";
}
