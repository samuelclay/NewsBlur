package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserProfile;

public class SocialFeedResponse extends NewsBlurResponse {
	
	@SerializedName("stories")
	public Story[] stories;
	
	@SerializedName("feeds")
	public Feed[] feeds;
	
	@SerializedName("user_profiles")
	public UserProfile[] userProfiles;
	

}
