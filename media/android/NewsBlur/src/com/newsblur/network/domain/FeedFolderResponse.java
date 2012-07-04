package com.newsblur.network.domain;

import java.util.Map;

import com.google.gson.annotations.SerializedName;
import com.newsblur.domain.Feed;
import com.newsblur.domain.FolderStructure;

public class FeedFolderResponse {
	
	@SerializedName("starred_count")
	public int starredCount;
	
	@SerializedName("feeds")
	public Map<String, Feed> feeds;
	
	@SerializedName("folders")
	public FolderStructure folderStructure;
	

}
