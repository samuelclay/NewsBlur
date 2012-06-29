package com.newsblur.domain;

import java.util.Map;

import com.google.gson.annotations.SerializedName;

public class FeedUpdate {
	
	@SerializedName("starred_count")
	public int starredCount;
	
	@SerializedName("feeds")
	public Map<String, Feed> feeds;
	
	@SerializedName("folders")
	public FolderStructure folderStructure;
	

}
