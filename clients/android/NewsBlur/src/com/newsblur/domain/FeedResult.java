package com.newsblur.domain;

import com.google.gson.annotations.SerializedName;

public class FeedResult {

	@SerializedName("num_subscribers")
	public int numberOfSubscriber;
	
	@SerializedName("favicon_color")
	public String faviconColor;
	
	@SerializedName("value")
	public String url;
	
	public String tagline;
	
	public String label;
	
	public String id;
	
	public String favicon;
	
}
