package com.newsblur.network;

import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map.Entry;

import org.apache.http.HttpStatus;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.text.TextUtils;
import android.webkit.CookieManager;
import android.webkit.CookieSyncManager;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Feed;
import com.newsblur.domain.FeedResult;
import com.newsblur.domain.Folder;
import com.newsblur.domain.Reply;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserProfile;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.domain.CategoriesResponse;
import com.newsblur.network.domain.FeedFolderResponse;
import com.newsblur.network.domain.FeedRefreshResponse;
import com.newsblur.network.domain.LoginResponse;
import com.newsblur.network.domain.Message;
import com.newsblur.network.domain.ProfileResponse;
import com.newsblur.network.domain.SocialFeedResponse;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.serialization.BooleanTypeAdapter;
import com.newsblur.serialization.DateStringTypeAdapter;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;

public class APIManager {

	private Context context;
	private Gson gson;
	private ContentResolver contentResolver;

	public APIManager(final Context context) {
		this.context = context;
		this.contentResolver = context.getContentResolver();
        this.gson = new GsonBuilder()
                .registerTypeAdapter(Date.class, new DateStringTypeAdapter())
                .registerTypeAdapter(Boolean.class, new BooleanTypeAdapter())
                .registerTypeAdapter(boolean.class, new BooleanTypeAdapter())
                .create();
	}

	public LoginResponse login(final String username, final String password) {
		final APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERNAME, username);
		values.put(APIConstants.PARAMETER_PASSWORD, password);
		final APIResponse response = client.post(APIConstants.URL_LOGIN, values);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			LoginResponse loginResponse = gson.fromJson(response.responseString, LoginResponse.class);
			PrefsUtils.saveLogin(context, username, response.cookie);
			return loginResponse;
		} else {
			return new LoginResponse();
		}		
	}

	public boolean setAutoFollow(boolean autofollow) {
		final APIClient client = new APIClient(context);
		ContentValues values = new ContentValues();
		values.put("autofollow_friends", autofollow ? "true" : "false");
		final APIResponse response = client.post(APIConstants.URL_AUTOFOLLOW_PREF, values);
		return (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected);
	}

	public boolean addCategories(ArrayList<String> categories) {
		final APIClient client = new APIClient(context);
		final ValueMultimap values = new ValueMultimap();
		for (String category : categories) {
			values.put(APIConstants.PARAMETER_CATEGORY, URLEncoder.encode(category));
		}
		final APIResponse response = client.post(APIConstants.URL_ADD_CATEGORIES, values, false);
		return (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected);
	}

	public boolean markFeedAsRead(final String[] feedIds) {
		final APIClient client = new APIClient(context);
		final ValueMultimap values = new ValueMultimap();
		for (String feedId : feedIds) {
			values.put(APIConstants.PARAMETER_FEEDID, feedId);
		}
		final APIResponse response = client.post(APIConstants.URL_MARK_FEED_AS_READ, values, false);
		if (!response.isOffline && response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			return true;
		} else {
			return false;
		}
	}
	
	public boolean markAllAsRead() {
		final APIClient client = new APIClient(context);
		final ValueMultimap values = new ValueMultimap();
		values.put(APIConstants.PARAMETER_DAYS, "0");
		final APIResponse response = client.post(APIConstants.URL_MARK_ALL_AS_READ, values, false);
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

	public boolean markStoryAsStarred(final String feedId, final String storyId) {
		final APIClient client = new APIClient(context);
		final ValueMultimap values = new ValueMultimap();
		values.put(APIConstants.PARAMETER_FEEDID, feedId);
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		final APIResponse response = client.post(APIConstants.URL_MARK_STORY_AS_STARRED, values, false);
		if (!response.isOffline && response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			return true;
		} else {
			return false;
		}
	}

	public CategoriesResponse getCategories() {
		final APIClient client = new APIClient(context);
		final APIResponse response = client.get(APIConstants.URL_CATEGORIES);
		if (!response.isOffline && response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			return gson.fromJson(response.responseString, CategoriesResponse.class);
		} else {
			return null;
		}
	}

	public LoginResponse signup(final String username, final String password, final String email) {
		final APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERNAME, username);
		values.put(APIConstants.PARAMETER_PASSWORD, password);
		values.put(APIConstants.PARAMETER_EMAIL, email);
		final APIResponse response = client.post(APIConstants.URL_SIGNUP, values);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			LoginResponse loginResponse = gson.fromJson(response.responseString, LoginResponse.class);
			PrefsUtils.saveLogin(context, username, response.cookie);

			CookieSyncManager.createInstance(context.getApplicationContext());
			CookieManager cookieManager = CookieManager.getInstance();

			cookieManager.setCookie(".newsblur.com", response.cookie);
			CookieSyncManager.getInstance().sync();

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
			PrefsUtils.saveUserDetails(context, profileResponse.user);
			return profileResponse;
		} else {
			return null;
		}
	}

	public StoriesResponse getStoriesForFeed(String feedId, String pageNumber, StoryOrder order, ReadFilter filter) {
		final APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		Uri feedUri = Uri.parse(APIConstants.URL_FEED_STORIES).buildUpon().appendPath(feedId).build();
		values.put(APIConstants.PARAMETER_FEEDS, feedId);
		values.put(APIConstants.PARAMETER_PAGE_NUMBER, pageNumber);
		values.put(APIConstants.PARAMETER_ORDER, order.getParameterValue());
		values.put(APIConstants.PARAMETER_READ_FILTER, filter.getParameterValue());

		final APIResponse response = client.get(feedUri.toString(), values);
		Uri storyUri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(feedId).build();

		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			if (TextUtils.equals(pageNumber, "1")) {
				contentResolver.delete(storyUri, null, null);
			}
			StoriesResponse storiesResponse = gson.fromJson(response.responseString, StoriesResponse.class);

			Uri classifierUri = FeedProvider.CLASSIFIER_URI.buildUpon().appendPath(feedId).build();

			contentResolver.delete(classifierUri, null, null);

			for (ContentValues classifierValues : storiesResponse.classifiers.getContentValues()) {
				contentResolver.insert(classifierUri, classifierValues);
			}

			for (Story story : storiesResponse.stories) {
				contentResolver.insert(storyUri, story.getValues());
				insertComments(story);
			}

			for (UserProfile user : storiesResponse.users) {
				contentResolver.insert(FeedProvider.USERS_URI, user.getValues());
			}

			return storiesResponse;
		} else {
			return null;
		}
	}

	public StoriesResponse getStoriesForFeeds(String[] feedIds, String pageNumber, StoryOrder order, ReadFilter filter) {
		final APIClient client = new APIClient(context);
		final ValueMultimap values = new ValueMultimap();
		for (String feedId : feedIds) {
			values.put(APIConstants.PARAMETER_FEEDS, feedId);
		}
		if (!TextUtils.isEmpty(pageNumber)) {
			values.put(APIConstants.PARAMETER_PAGE_NUMBER, "" + pageNumber);
		}
		values.put(APIConstants.PARAMETER_ORDER, order.getParameterValue());
		values.put(APIConstants.PARAMETER_READ_FILTER, filter.getParameterValue());
		final APIResponse response = client.get(APIConstants.URL_RIVER_STORIES, values);

		StoriesResponse storiesResponse = gson.fromJson(response.responseString, StoriesResponse.class);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			if (TextUtils.equals(pageNumber,"1")) {
				Uri storyUri = FeedProvider.ALL_STORIES_URI;
				contentResolver.delete(storyUri, null, null);
			}

			for (Story story : storiesResponse.stories) {
				Uri storyUri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(story.feedId).build();
				contentResolver.insert(storyUri, story.getValues());
				insertComments(story);
			}

			for (UserProfile user : storiesResponse.users) {
				contentResolver.insert(FeedProvider.USERS_URI, user.getValues());
			}

			return storiesResponse;
		} else {
			return null;
		}
	}

	public StoriesResponse getStarredStories(String pageNumber) {
		final APIClient client = new APIClient(context);
		final ValueMultimap values = new ValueMultimap();
		if (!TextUtils.isEmpty(pageNumber)) {
			values.put(APIConstants.PARAMETER_PAGE_NUMBER, "" + pageNumber);
		}
		final APIResponse response = client.get(APIConstants.URL_STARRED_STORIES, values);

		StoriesResponse storiesResponse = gson.fromJson(response.responseString, StoriesResponse.class);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			if (TextUtils.equals(pageNumber,"1")) {
				contentResolver.delete(FeedProvider.STARRED_STORIES_URI, null, null);
			}
			for (Story story : storiesResponse.stories) {
				contentResolver.insert(FeedProvider.STARRED_STORIES_URI, story.getValues());
				insertComments(story);
			}
			for (UserProfile user : storiesResponse.users) {
				contentResolver.insert(FeedProvider.USERS_URI, user.getValues());
			}
			return storiesResponse;
		} else {
			return null;
		}
	}

	public SocialFeedResponse getSharedStoriesForFeeds(String[] feedIds, String pageNumber) {
		final APIClient client = new APIClient(context);
		final ValueMultimap values = new ValueMultimap();
		for (String feedId : feedIds) {
			values.put(APIConstants.PARAMETER_FEEDS, feedId);
		}
		if (!TextUtils.isEmpty(pageNumber)) {
			values.put(APIConstants.PARAMETER_PAGE_NUMBER, "" + pageNumber);
		}

		final APIResponse response = client.get(APIConstants.URL_SHARED_RIVER_STORIES, values);

		SocialFeedResponse storiesResponse = gson.fromJson(response.responseString, SocialFeedResponse.class);
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {

			// If we've successfully retrieved the latest stories for all shared feeds (the first page), delete all previous shared feeds
			if (TextUtils.equals(pageNumber,"1")) {
				Uri storyUri = FeedProvider.ALL_STORIES_URI;
				contentResolver.delete(storyUri, null, null);
			}

			for (Story story : storiesResponse.stories) {
				for (String userId : story.sharedUserIds) {
					Uri storySocialUri = FeedProvider.SOCIALFEED_STORIES_URI.buildUpon().appendPath(userId).build();
					contentResolver.insert(storySocialUri, story.getValues());
				}

				Uri storyUri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(story.feedId).build();
				contentResolver.insert(storyUri, story.getValues());

				insertComments(story);
			}

			for (UserProfile user : storiesResponse.userProfiles) {
				contentResolver.insert(FeedProvider.USERS_URI, user.getValues());
			}

			if (storiesResponse != null && storiesResponse.feeds!= null) {
				for (Feed feed : storiesResponse.feeds) {
					contentResolver.insert(FeedProvider.FEEDS_URI, feed.getValues());
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

			Uri storySocialUri = FeedProvider.SOCIALFEED_STORIES_URI.buildUpon().appendPath(userId).build();
			if (TextUtils.equals(pageNumber, "1")) {
				contentResolver.delete(storySocialUri, null, null);
			}

			for (Story story : socialFeedResponse.stories) {
				insertComments(story);

				Uri storyUri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(story.feedId).build();
				contentResolver.insert(storyUri, story.getValues());
				contentResolver.insert(storySocialUri, story.getValues());
			}

			if (socialFeedResponse.userProfiles != null) {
				for (UserProfile user : socialFeedResponse.userProfiles) {
					contentResolver.insert(FeedProvider.USERS_URI, user.getValues());
				}
			}

			for (Feed feed : socialFeedResponse.feeds) {
				contentResolver.insert(FeedProvider.FEEDS_URI, feed.getValues());
			}
			return socialFeedResponse;
		} else {
			return null;
		}
	}

	private void insertComments(Story story) {
		for (Comment comment : story.publicComments) {
			StringBuilder builder = new StringBuilder();
			builder.append(story.id);
			builder.append(story.feedId);
			builder.append(comment.userId);
			comment.storyId = story.id;
			comment.id = (builder.toString());
			contentResolver.insert(FeedProvider.COMMENTS_URI, comment.getValues());

			for (Reply reply : comment.replies) {
				reply.commentId = comment.id;
				contentResolver.insert(FeedProvider.REPLIES_URI, reply.getValues());
			}
		}

		for (Comment comment : story.friendsComments) {
			StringBuilder builder = new StringBuilder();
			builder.append(story.id);
			builder.append(story.feedId);
			builder.append(comment.userId);
			comment.storyId = story.id;
			comment.id = (builder.toString());
			comment.byFriend = true;
			contentResolver.insert(FeedProvider.COMMENTS_URI, comment.getValues());

			for (Reply reply : comment.replies) {
				reply.commentId = comment.id;
				contentResolver.insert(FeedProvider.REPLIES_URI, reply.getValues());
			}
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

	/**
     * Fetch the list of feeds/folders/socials from the backend.
     * 
     * @param doUpdateCounts forces a refresh of unread counts.  This has a high latency
     *        cost and should not be set if the call is being used to display the UI for
     *        the first time, in which case it is more appropriate to make a separate,
     *        additional call to refreshFeedCounts().
     */
    public boolean getFolderFeedMapping(boolean doUpdateCounts) {
		
		final APIClient client = new APIClient(context);
		final ContentValues params = new ContentValues();
		params.put( APIConstants.PARAMETER_UPDATE_COUNTS, (doUpdateCounts ? "true" : "false") );
		final APIResponse response = client.get(APIConstants.URL_FEEDS, params);
		final FeedFolderResponse feedUpdate = new FeedFolderResponse(response.responseString, gson); 
		
		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {

            // if the response says we aren't logged in, clear the DB and prompt for login. We test this
            // here, since this the first sync call we make on launch if we believe we are cookied.
            if (! feedUpdate.isAuthenticated) {
                PrefsUtils.logout(context);
                return false;
            }
			
			HashMap<String, Feed> existingFeeds = getExistingFeeds();
			
			List<ContentValues> feedValues = new ArrayList<ContentValues>();
			for (String newFeedId : feedUpdate.feeds.keySet()) {
				if (existingFeeds.get(newFeedId) == null || !feedUpdate.feeds.get(newFeedId).equals(existingFeeds.get(newFeedId))) {
					feedValues.add(feedUpdate.feeds.get(newFeedId).getValues());
				}
			}
			if(feedValues.size() > 0) {
				contentResolver.bulkInsert(FeedProvider.FEEDS_URI, feedValues.toArray(new ContentValues[feedValues.size()]));
			}
			
			for (String olderFeedId : existingFeeds.keySet()) {
				if (feedUpdate.feeds.get(olderFeedId) == null) {
					Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(olderFeedId).build();
					contentResolver.delete(feedUri, null, null);
				}
			}
			
			List<ContentValues> socialFeedValues = new ArrayList<ContentValues>();
			for (final SocialFeed feed : feedUpdate.socialFeeds) {
				socialFeedValues.add(feed.getValues());
			}
			if(socialFeedValues.size() > 0) {
				contentResolver.bulkInsert(FeedProvider.SOCIAL_FEEDS_URI, socialFeedValues.toArray(new ContentValues[socialFeedValues.size()]));
			}
			
			Cursor folderCursor = contentResolver.query(FeedProvider.FOLDERS_URI, null, null, null, null);
			folderCursor.moveToFirst();
			HashSet<String> existingFolders = new HashSet<String>();
			while (!folderCursor.isAfterLast()) {
				existingFolders.add(Folder.fromCursor(folderCursor).getName());
				folderCursor.moveToNext();
			}
			folderCursor.close();
			
			for (final Entry<String, List<Long>> entry : feedUpdate.folders.entrySet()) {
				if (!TextUtils.isEmpty(entry.getKey())) {
					String folderName = entry.getKey().trim();
					if (!existingFolders.contains(folderName) && !TextUtils.isEmpty(folderName)) {
						final ContentValues folderValues = new ContentValues();
						folderValues.put(DatabaseConstants.FOLDER_NAME, folderName);
						contentResolver.insert(FeedProvider.FOLDERS_URI, folderValues);
					}
	
					for (Long feedId : entry.getValue()) {
						if (!existingFeeds.containsKey(Long.toString(feedId))) {
							ContentValues values = new ContentValues(); 
							values.put(DatabaseConstants.FEED_FOLDER_FEED_ID, feedId);
							values.put(DatabaseConstants.FEED_FOLDER_FOLDER_NAME, folderName);
							contentResolver.insert(FeedProvider.FEED_FOLDER_MAP_URI, values);
						}
					}
				}
			}

            int starredStoriesCount = feedUpdate.starredCount;
            ContentValues values = new ContentValues();
            values.put(DatabaseConstants.STARRED_STORY_COUNT_COUNT, starredStoriesCount);
            contentResolver.insert(FeedProvider.STARRED_STORIES_COUNT_URI, values);

		}
		return true;
	}

	private HashMap<String, Feed> getExistingFeeds() {
		Cursor feedCursor = contentResolver.query(FeedProvider.FEEDS_URI, null, null, null, null);
		feedCursor.moveToFirst();
		HashMap<String, Feed> existingFeeds = new HashMap<String, Feed>();
		while (!feedCursor.isAfterLast()) {
			existingFeeds.put(Feed.fromCursor(feedCursor).feedId, Feed.fromCursor(feedCursor));
			feedCursor.moveToNext();
		}
		feedCursor.close();
		return existingFeeds;
	}
	
	public boolean trainClassifier(String feedId, String key, int type, int action) {
		String typeText = null;
		String actionText = null;

		switch (type) {
		case Classifier.AUTHOR:
			typeText = "author"; 
			break;
		case Classifier.TAG:
			typeText = "tag";
			break;
		case Classifier.TITLE:
			typeText = "title";
			break;
		case Classifier.FEED:
			typeText = "feed";
			break;	
		}

		switch (action) {
		case Classifier.CLEAR_LIKE:
			actionText = "remove_like_"; 
			break;
		case Classifier.CLEAR_DISLIKE:
			actionText = "remove_dislike_"; 
			break;	
		case Classifier.LIKE:
			actionText = "like_";
			break;
		case Classifier.DISLIKE:
			actionText = "dislike_";
			break;	
		}

		StringBuilder builder = new StringBuilder();;
		builder.append(actionText);
		builder.append(typeText);

		ContentValues values = new ContentValues();
		if (type == Classifier.FEED) {
			values.put(builder.toString(), feedId);
		} else {
			values.put(builder.toString(), key);
		}
		values.put(APIConstants.PARAMETER_FEEDID, feedId);

		final APIClient client = new APIClient(context);
		final APIResponse response = client.post(APIConstants.URL_CLASSIFIER_SAVE, values);
		return (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected);
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

	public boolean favouriteComment(String storyId, String commentId, String feedId) {
		final APIClient client = new APIClient(context);
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		values.put(APIConstants.PARAMETER_STORY_FEEDID, feedId);
		values.put(APIConstants.PARAMETER_COMMENT_USERID, commentId);
		final APIResponse response = client.post(APIConstants.URL_LIKE_COMMENT, values);
		return (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected);
	}

	public Boolean unFavouriteComment(String storyId, String commentId, String feedId) {
		final APIClient client = new APIClient(context);
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		values.put(APIConstants.PARAMETER_STORY_FEEDID, feedId);
		values.put(APIConstants.PARAMETER_COMMENT_USERID, commentId);
		final APIResponse response = client.post(APIConstants.URL_UNLIKE_COMMENT, values);
		return (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected);
	}

	public boolean replyToComment(String storyId, String storyFeedId, String commentUserId, String reply) {
		final APIClient client = new APIClient(context);
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		values.put(APIConstants.PARAMETER_STORY_FEEDID, storyFeedId);
		values.put(APIConstants.PARAMETER_COMMENT_USERID, commentUserId);
		values.put(APIConstants.PARAMETER_REPLY_TEXT, reply);
		final APIResponse response = client.post(APIConstants.URL_REPLY_TO, values);
		return (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected);
	}

	public boolean markMultipleStoriesAsRead(ContentValues values) {
		final APIClient client = new APIClient(context);
		final APIResponse response = client.post(APIConstants.URL_MARK_FEED_STORIES_AS_READ, values);
		if (!response.isOffline && response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			return true;
		} else {
			return false;
		}
	}

	public boolean addFeed(String feedUrl, String folderName) {
		final APIClient client = new APIClient(context);
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_URL, feedUrl);
		if (!TextUtils.isEmpty(folderName)) {
			values.put(APIConstants.PARAMETER_FOLDER, folderName);
		}
		final APIResponse response = client.post(APIConstants.URL_ADD_FEED, values);
		return (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected);
	}

	public FeedResult[] searchForFeed(String searchTerm) throws ServerErrorException {
		final APIClient client = new APIClient(context);
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_FEED_SEARCH_TERM, searchTerm);
		final APIResponse response = client.get(APIConstants.URL_FEED_AUTOCOMPLETE, values);

		if (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected) {
			return fromJson(response.responseString, FeedResult[].class);
		} else {
			return null;
		}
	}

	public boolean deleteFeed(long feedId, String folderName) {
		final APIClient client = new APIClient(context);
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_FEEDID, Long.toString(feedId));
		if (!TextUtils.isEmpty(folderName)) {
			values.put(APIConstants.PARAMETER_IN_FOLDER, folderName);
		}
		final APIResponse response = client.post(APIConstants.URL_DELETE_FEED, values);
		return (response.responseCode == HttpStatus.SC_OK && !response.hasRedirected);
	}

	private <T> T fromJson(String json, Class<T> classOfT) throws ServerErrorException {
		if(isServerMessage(json)) {
			Message errorMessage = gson.fromJson(json, Message.class);
			throw new ServerErrorException(errorMessage.message);
		}
		return gson.fromJson(json, classOfT);
	}

	private boolean isServerMessage(String json) {
		// TODO find a better way to identify these failed responses
		boolean isServerMessage = false;
		JsonParser parser = new JsonParser();
		JsonElement jsonElement = parser.parse(json);
		if(jsonElement.isJsonObject()) {
			JsonObject asJsonObject = jsonElement.getAsJsonObject();
			if(asJsonObject.has("code")) {
				JsonElement codeItem = asJsonObject.get("code");
				int code = codeItem.getAsInt();
				if(code == -1)
					isServerMessage = true;
			}
		}
		return isServerMessage;
	}
}
