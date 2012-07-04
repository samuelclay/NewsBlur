package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;
import com.newsblur.domain.UserProfile;

public class ProfileResponse {
	
	@SerializedName("user_profile")
	public UserProfile user;
	
}
