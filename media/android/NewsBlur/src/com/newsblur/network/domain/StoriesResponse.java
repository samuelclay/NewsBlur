package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;

public class StoriesResponse {
	
	@SerializedName("stories")
	public Story[] stories;
	
	public Classifier classifiers;
	
	public boolean authenticated;

}
