package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;
import com.newsblur.domain.UserDetails;

public class ProfileResponse {
	
	@SerializedName("user_profile")
	public UserDetails user;
	
	@SerializedName("activities")
	public ActivitiesResponse[] activities;
	
}
