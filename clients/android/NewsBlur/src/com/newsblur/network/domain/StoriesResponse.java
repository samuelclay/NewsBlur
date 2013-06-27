package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserProfile;

public class StoriesResponse {
	
	@SerializedName("stories")
	public Story[] stories;
	
	@SerializedName("user_profiles")
	public UserProfile[] users;
	
	public Classifier classifiers;
	
	public boolean authenticated;

}
