package com.newsblur.domain;

import com.google.gson.annotations.SerializedName;


// A UserDetails object is distinct from a UserProfile in that it contains more data and is
// only requested on its own. A UserProfile is include with feed/story requests.
public class UserDetails {

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
	
	@SerializedName("followed_by_you")
	public boolean followedByYou;
	
	@SerializedName("following_you")
	public boolean followsYou;

	@SerializedName("photo_url")
	public String photoUrl;	

}
