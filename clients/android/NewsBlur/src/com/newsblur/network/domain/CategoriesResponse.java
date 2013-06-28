package com.newsblur.network.domain;

import java.util.HashMap;

import com.google.gson.annotations.SerializedName;
import com.newsblur.domain.Category;
import com.newsblur.domain.Feed;

public class CategoriesResponse {
	
	@SerializedName("feeds")
	public HashMap<String, Feed> feeds;

	
	@SerializedName("categories")
	public Category[] categories;
	
}
