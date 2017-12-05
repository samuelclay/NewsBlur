package com.newsblur.network.domain;

import java.util.List;
import java.util.Map;

import com.google.gson.annotations.SerializedName;

import com.newsblur.domain.Classifier;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserProfile;

public class StoriesResponse extends NewsBlurResponse {
	
    // some APIs (rivers) return many stories
	@SerializedName("stories")
	public Story[] stories;

    // other APIs (shares) return a single updated story
    @SerializedName("story")
    public Story story;
	
	@SerializedName("user_profiles")
	public UserProfile[] users;
	
	public Map<String,Classifier> classifiers;
	
    // some stories responses (like those from social feeds) also include feed data for non-subscribed feeds
	@SerializedName("feeds")
	public List<Feed> feeds;

    // responses for single feeds include some metadata related to the feed, not the stories
    @SerializedName("feed_tags")
    public String[][] feedTags;
    @SerializedName("feed_authors")
    public String[][] feedAuthors;

}
