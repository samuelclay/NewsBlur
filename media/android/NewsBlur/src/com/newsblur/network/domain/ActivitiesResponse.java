package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;

public class ActivitiesResponse {
	
	public String category;
	public String content;
	public String title;
	
	@SerializedName("time_since")
	public String timeSince;
	
	@SerializedName("with_user")
	public WithUser user;
	
	@SerializedName("with_user_id")
	public String id;
	
	
	public class WithUser {
		public String username;
		
		@SerializedName("photo_url")
		public String photoUrl;
		
	}
	
}

