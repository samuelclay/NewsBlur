package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;
import com.newsblur.domain.ActivityDetails;
import com.newsblur.domain.UserDetails;

public class ProfileResponse extends NewsBlurResponse {
	
	@SerializedName("user_profile")
	public UserDetails user;
	
	@SerializedName("activities")
	public ActivityDetails[] activities;
	
}
