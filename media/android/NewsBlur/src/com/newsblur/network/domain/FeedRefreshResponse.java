package com.newsblur.network.domain;

import java.util.Map;

import android.content.ContentValues;

import com.google.gson.annotations.SerializedName;
import com.newsblur.database.DatabaseConstants;

public class FeedRefreshResponse {

	
	@SerializedName("feeds")
	public Map<String, Count> feedCounts;
	
	@SerializedName("social_feeds")
	public Map<String, Count> socialfeedCounts;
	
	public class Count {
	
		@SerializedName("ps")
		int positive;
		
		@SerializedName("ng")
		int negative;
		
		@SerializedName("nt")
		int neutral;
	
		public ContentValues getValues() {
			ContentValues values = new ContentValues();
			values.put(DatabaseConstants.FEED_NEGATIVE_COUNT, negative);
			values.put(DatabaseConstants.FEED_NEUTRAL_COUNT, neutral);
			values.put(DatabaseConstants.FEED_POSITIVE_COUNT, positive);
			return values;
		}
		
	}
	
}
