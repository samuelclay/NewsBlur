package com.newsblur.network.domain;

import java.io.Serializable;

import com.google.gson.annotations.SerializedName;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;

public class SocialFeedResponse implements Serializable {
	
	private static final long serialVersionUID = 1L;

	@SerializedName("stories")
	public Story[] stories;
	
	@SerializedName("feeds")
	public Feed[] feeds;
	
	public boolean authenticated;

}