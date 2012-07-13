package com.newsblur.domain;

import com.google.gson.annotations.SerializedName;

public class UserProfile {

	public String username;
	public String website;
	public String bio;
	public String location;
	public String id;

	@SerializedName("following_user_ids")
	public int[] followingUserIds;

	@SerializedName("follower_user_ids")
	public int[] followerUserIds;

	@SerializedName("num_subscribers")
	public int numberOfSubscribers;

	@SerializedName("average_stories_per_month")
	public int averageStoriesPerMonth;

	@SerializedName("following_count")
	public int followingCount;

	@SerializedName("feed_address")
	public String feedAddress;

	@SerializedName("subscription_count")
	public int subscriptionCount;

	@SerializedName("feed_title")
	public String feedTitle;

	@SerializedName("shared_stories_count")
	public int sharedStoriesCount;

	@SerializedName("photo_service")
	public String photoService;

	@SerializedName("stories_last_month")
	public int storiesLastMonth;

	@SerializedName("follower_count")
	public int followerCount;

	@SerializedName("user_id")
	public String userId;

	@SerializedName("feed_link")
	public String feedLink;

	@SerializedName("popular_publishers")
	public Publisher[] popularPublishers;

	@SerializedName("photo_url")
	public String photoUrl;	

	public class Publisher {
		
		@SerializedName("story_count")
		int storyCount;
		
		@SerializedName("feed_title")
		String feedTitle;
		
		int id;
	}
	
}