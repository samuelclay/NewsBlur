package com.newsblur.network.domain;

import java.util.List;
import java.util.Map;

import com.google.gson.annotations.SerializedName;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SocialFeed;

public class FeedFolderResponse {
	
	@SerializedName("starred_count")
	public int starredCount;
	
	@SerializedName("feeds")
	public Map<String, Feed> feeds;
	
	@SerializedName("flat_folders")
	public Map<String, List<Long>> folders;
	
	@SerializedName("social_feeds")
	public SocialFeed[] socialFeeds;
	

}
