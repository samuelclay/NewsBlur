package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;

import java.util.List;
import java.util.Map;

public class UnreadStoryHashesResponse extends NewsBlurResponse {
	
	@SerializedName("unread_feed_story_hashes")
	public Map<String,List<String[]>> unreadHashes; 
    // the inner, key-less array contains an ordered pair of story hash and timestamp
	
}
