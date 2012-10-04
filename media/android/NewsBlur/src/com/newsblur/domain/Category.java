package com.newsblur.domain;

import com.google.gson.annotations.SerializedName;

public class Category {

	public String title;
	public String description;
	
	@SerializedName("feed_ids")
	public String[] feedIds;
	
}
