package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;

import java.util.Map;

public class UnreadStoryHashesResponse extends NewsBlurResponse {
	
	@SerializedName("unread_feed_story_hashes")
	public Map<String,String[]> unreadHashes; 
	
}
