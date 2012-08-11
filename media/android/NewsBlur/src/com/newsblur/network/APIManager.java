package com.newsblur.network;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Map.Entry;

import org.apache.http.HttpStatus;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.net.Uri;
import android.text.TextUtils;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.newsblur.R;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Feed;
import com.newsblur.domain.FolderStructure;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.Story;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.domain.FeedFolderResponse;
import com.newsblur.network.domain.FeedRefreshResponse;
import com.newsblur.network.domain.LoginResponse;
import com.newsblur.network.domain.ProfileResponse;
import com.newsblur.network.domain.SocialFeedResponse;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.serialization.DateStringTypeAdapter;
import com.newsblur.serialization.FolderStructureTypeAdapter;
import com.newsblur.util.PrefsUtil;

public class APIManager {

	private static final String TAG = "APIManager";
	private Context context;
	private Gson gson;
	private ContentResolver contentResolver;

	public APIManager(final Context context) {
		this.context = context;
		final GsonBuilder builder = new GsonBuilder();
		builder.registerTypeAdapter(FolderStructure.class, new FolderStructureTypeAdapter());
		builder.registerTypeAdapter(Date.class, new DateStringTypeAdapter());
		contentResolver = context.getContentResolver();
		gson = builder.create();
	}

	public LoginResponse login(final String username, final String password) {
		final APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERNAME, username);
		values.put(APIConstants.PARAMETER_PASSWORD, password);
		final APIResponse response = client.post(APIConstants.URL_LOGIN, values);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			LoginResponse loginResponse = gson.fromJson(response.responseString, LoginResponse.class);
			PrefsUtil.saveCookie(context, response.cookie);
			return loginResponse;
		} else {
			return new LoginResponse();
		}		
	}

	public boolean markFeedAsRead(final String[] feedIds) {
		final APIClient client = new APIClient(context);
		final ValueMultimap values = new ValueMultimap();
		for (String feedId : feedIds) {
			values.put(APIConstants.PARAMETER_FEEDID, feedId);
		}
		final APIResponse response = client.post(APIConstants.URL_MARK_FEED_AS_READ, values);
		if (!response.isOffline && response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			return true;
		} else {
			return false;
		}
	}
	
	public boolean markStoryAsRead(final String feedId, final ArrayList<String> storyIds) {
		final APIClient client = new APIClient(context);
		final ValueMultimap values = new ValueMultimap();
		values.put(APIConstants.PARAMETER_FEEDID, feedId);
		for (String storyId : storyIds) {
			values.put(APIConstants.PARAMETER_STORYID, storyId);
		}
		final APIResponse response = client.post(APIConstants.URL_MARK_STORY_AS_READ, values);
		if (!response.isOffline && response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			return true;
		} else {
			return false;
		}
	}
	
	public boolean markSocialStoryAsRead(final String updateJson) {
		final APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_MARKSOCIAL_JSON, updateJson);
		final APIResponse response = client.post(APIConstants.URL_MARK_SOCIALSTORY_AS_READ, values);
		if (!response.isOffline && response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			return true;
		} else {
			return false;
		}
	}

	public LoginResponse signup(final String username, final String password) {
		final APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERNAME, username);
		values.put(APIConstants.PARAMETER_PASSWORD, password);
		final APIResponse response = client.post(APIConstants.URL_SIGNUP, values);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			LoginResponse loginResponse = gson.fromJson(response.responseString, LoginResponse.class);
			PrefsUtil.saveCookie(context, response.cookie);
			return loginResponse;
		} else {
			return new LoginResponse();
		}		
	}

	public ProfileResponse updateUserProfile() {
		final APIClient client = new APIClient(context);
		final APIResponse response = client.get(APIConstants.URL_MY_PROFILE);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			ProfileResponse profileResponse = gson.fromJson(response.responseString, ProfileResponse.class);
			PrefsUtil.saveUserDetails(context, profileResponse.user);
			return profileResponse;
		} else {
			return null;
		}
	}

	public StoriesResponse getStoriesForFeed(String feedId, String pageNumber) {
		final APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_FEEDS, feedId);
		if (!TextUtils.isEmpty(pageNumber)) {
			values.put(APIConstants.PARAMETER_PAGE_NUMBER, "" + pageNumber);
		}
		Uri feedUri = Uri.parse(APIConstants.URL_FEED_STORIES).buildUpon().appendPath(feedId).build();
		final APIResponse response = client.get(feedUri.toString(), values);
		StoriesResponse storiesResponse = gson.fromJson(response.responseString, StoriesResponse.class);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			Uri storyUri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(feedId).build();
			for (Story story : storiesResponse.stories) {
				contentResolver.insert(storyUri, story.getValues());
				for (Comment comment : story.comments) {
					StringBuilder builder = new StringBuilder();
					builder.append(story.id);
					builder.append(story.feedId);
					builder.append(comment.userId);
					comment.storyId = story.id;
					comment.id = (builder.toString());
					contentResolver.insert(FeedProvider.COMMENTS_URI, comment.getValues());
				}
			}
			return storiesResponse;
		} else {
			return null;
		}
	}
	
	public SocialFeedResponse getStoriesForSocialFeed(String userId, String username, String pageNumber) {
		final APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USER_ID, userId);
		values.put(APIConstants.PARAMETER_USERNAME, username);
		if (!TextUtils.isEmpty(pageNumber)) {
			values.put(APIConstants.PARAMETER_PAGE_NUMBER, "" + pageNumber);
		}
		Uri feedUri = Uri.parse(APIConstants.URL_SOCIALFEED_STORIES).buildUpon().appendPath(userId).appendPath(username).build();
		final APIResponse response = client.get(feedUri.toString(), values);
		SocialFeedResponse socialFeedResponse = gson.fromJson(response.responseString, SocialFeedResponse.class);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			for (Story story : socialFeedResponse.stories) {
				Uri storyUri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(story.feedId).build();
				contentResolver.insert(storyUri, story.getValues());

				for (Comment comment : story.comments) {
					StringBuilder builder = new StringBuilder();
					builder.append(story.id);
					builder.append(story.feedId);
					builder.append(comment.userId);
					comment.storyId = story.id;
					comment.id = (builder.toString());
					contentResolver.insert(FeedProvider.COMMENTS_URI, comment.getValues());
				}
				
				Uri storySocialUri = FeedProvider.SOCIALFEED_STORIES_URI.buildUpon().appendPath(userId).build();
				contentResolver.insert(storySocialUri, story.getValues());
			}
			if (socialFeedResponse != null && socialFeedResponse .feeds!= null) {
				for (Feed feed : socialFeedResponse.feeds) {
					contentResolver.insert(FeedProvider.FEEDS_URI, feed.getValues());
				}
			}
			return socialFeedResponse;
		} else {
			return null;
		}
	}

	public boolean followUser(final String userId) {
		final APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERID, userId);
		final APIResponse response = client.post(APIConstants.URL_FOLLOW, values);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			return true;
		} else {
			return false;
		}
	}

	public boolean unfollowUser(final String userId) {
		final APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERID, userId);
		final APIResponse response = client.post(APIConstants.URL_UNFOLLOW, values);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			return true;
		} else {
			return false;
		}
	}
	
	public Boolean shareStory(final String storyId, final String feedId, final String comment, final String sourceUserId) {
		final APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		if (!TextUtils.isEmpty(comment)) {
			values.put(APIConstants.PARAMETER_SHARE_COMMENT, comment);
		}
		if (!TextUtils.isEmpty(sourceUserId)) {
			values.put(APIConstants.PARAMETER_SHARE_SOURCEID, sourceUserId);
		}
		values.put(APIConstants.PARAMETER_FEEDID, feedId);
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		
		final APIResponse response = client.post(APIConstants.URL_SHARE_STORY, values);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			return true;
		} else {
			return false;
		}
	}

	public void getFolderFeedMapping() {
		final APIClient client = new APIClient(context);
		final APIResponse response = client.get(APIConstants.URL_FEEDS);
		final FeedFolderResponse feedUpdate = gson.fromJson(response.responseString, FeedFolderResponse.class);

		for (final Entry<String, Feed> entry : feedUpdate.feeds.entrySet()) {
			final Feed feed = entry.getValue();
			contentResolver.insert(FeedProvider.FEEDS_URI, feed.getValues());
		}
		
		for (final SocialFeed feed : feedUpdate.socialFeeds) {
			contentResolver.insert(FeedProvider.SOCIAL_FEEDS_URI, feed.getValues());
		}
		
		String unsortedFolderName = context.getResources().getString(R.string.unsorted_folder_name);
		
		for (final Entry<String, List<Long>> entry : feedUpdate.folderStructure.folders.entrySet()) {
			String folderName = TextUtils.isEmpty(entry.getKey()) ? unsortedFolderName : entry.getKey();
			final ContentValues folderValues = new ContentValues();
			folderValues.put(DatabaseConstants.FOLDER_NAME, folderName);
			contentResolver.insert(FeedProvider.FOLDERS_URI, folderValues);

			for (Long feedId : entry.getValue()) {
				ContentValues values = new ContentValues(); 
				values.put(DatabaseConstants.FEED_FOLDER_FEED_ID, feedId);
				values.put(DatabaseConstants.FEED_FOLDER_FOLDER_NAME, folderName);
				contentResolver.insert(FeedProvider.FEED_FOLDER_MAP_URI, values);
			}
		}
	}

	public ProfileResponse getUser(String userId) {
		final APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USER_ID, userId);
		final APIResponse response = client.get(APIConstants.URL_USER_PROFILE, values);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			ProfileResponse profileResponse = gson.fromJson(response.responseString, ProfileResponse.class);
			return profileResponse;
		} else {
			return null;
		}
	}

	public void refreshFeedCounts() {
		final APIClient client = new APIClient(context);
		final APIResponse response = client.get(APIConstants.URL_FEED_COUNTS);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			final FeedRefreshResponse feedCountUpdate = gson.fromJson(response.responseString, FeedRefreshResponse.class);
			for (String feedId : feedCountUpdate.feedCounts.keySet()) {
				Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
				contentResolver.update(feedUri, feedCountUpdate.feedCounts.get(feedId).getValues(), null, null);
			}
			
			for (String socialfeedId : feedCountUpdate.socialfeedCounts.keySet()) {
				String userId = socialfeedId.split(":")[1];
				Uri feedUri = FeedProvider.SOCIAL_FEEDS_URI.buildUpon().appendPath(userId).build();
				contentResolver.update(feedUri, feedCountUpdate.socialfeedCounts.get(socialfeedId).getValues(), null, null);
			}
			
		}
	}

}
