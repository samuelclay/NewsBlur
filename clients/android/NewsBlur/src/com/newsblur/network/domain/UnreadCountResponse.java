package com.newsblur.network.domain;

import android.content.ContentValues;

import java.util.Map;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

public class UnreadCountResponse extends NewsBlurResponse {
	
	@SerializedName("feeds")
	public Map<String,UnreadMD> feeds;

	@SerializedName("social_feeds")
	public Map<String,UnreadMD> socialFeeds;

    public static class UnreadMD {

        public int ps;
        public int nt;
        public int ng;

        public ContentValues getValues() {
            ContentValues values = new ContentValues();
            values.put(DatabaseConstants.FEED_POSITIVE_COUNT, ps);
            values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, nt);
            values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, ng);
            values.put(DatabaseConstants.FEED_FETCH_PENDING, false);
            return values;
        }

        public ContentValues getValuesSocial() {
            ContentValues values = new ContentValues();
            values.put(DatabaseConstants.FEED_POSITIVE_COUNT, ps);
            values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, nt);
            values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, ng);
            return values;
        }

    }

}
