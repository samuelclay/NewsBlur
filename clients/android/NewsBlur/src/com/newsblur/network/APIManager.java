package com.newsblur.network;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.UnsupportedEncodingException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Map.Entry;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.SharedPreferences;
import android.net.Uri;
import android.text.TextUtils;
import android.util.Log;
import android.webkit.CookieManager;
import android.webkit.CookieSyncManager;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.newsblur.database.DatabaseConstants;
import com.newsblur.database.FeedProvider;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.Comment;
import com.newsblur.domain.Feed;
import com.newsblur.domain.FeedResult;
import com.newsblur.domain.Reply;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.Story;
import com.newsblur.domain.UserProfile;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.domain.CategoriesResponse;
import com.newsblur.network.domain.FeedFolderResponse;
import com.newsblur.network.domain.FeedRefreshResponse;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.network.domain.ProfileResponse;
import com.newsblur.network.domain.RegisterResponse;
import com.newsblur.network.domain.SocialFeedResponse;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.serialization.BooleanTypeAdapter;
import com.newsblur.serialization.DateStringTypeAdapter;
import com.newsblur.util.AppConstants;
import com.newsblur.util.NetworkUtils;
import com.newsblur.util.PrefConstants;
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

	public NewsBlurResponse login(final String username, final String password) {
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERNAME, username);
		values.put(APIConstants.PARAMETER_PASSWORD, password);
		final APIResponse response = post(APIConstants.URL_LOGIN, values);
        NewsBlurResponse loginResponse =  response.getResponse(gson);
		if (!response.isError()) {
			PrefsUtils.saveLogin(context, username, response.getCookie());
		} 
        return loginResponse;
    }

	public boolean setAutoFollow(boolean autofollow) {
		ContentValues values = new ContentValues();
		values.put("autofollow_friends", autofollow ? "true" : "false");
		final APIResponse response = post(APIConstants.URL_AUTOFOLLOW_PREF, values);
		return (!response.isError());
	}

	public boolean addCategories(ArrayList<String> categories) {
		final ValueMultimap values = new ValueMultimap();
		for (String category : categories) {
			values.put(APIConstants.PARAMETER_CATEGORY, URLEncoder.encode(category));
		}
		final APIResponse response = post(APIConstants.URL_ADD_CATEGORIES, values, false);
		return (!response.isError());
	}

	public boolean markFeedAsRead(final String[] feedIds) {
		final ValueMultimap values = new ValueMultimap();
		for (String feedId : feedIds) {
			values.put(APIConstants.PARAMETER_FEEDID, feedId);
		}
		final APIResponse response = post(APIConstants.URL_MARK_FEED_AS_READ, values, false);
		if (!response.isError()) {
			return true;
		} else {
			return false;
		}
	}
	
	public boolean markAllAsRead() {
		final ValueMultimap values = new ValueMultimap();
		values.put(APIConstants.PARAMETER_DAYS, "0");
		final APIResponse response = post(APIConstants.URL_MARK_ALL_AS_READ, values, false);
		if (!response.isError()) {
			return true;
		} else {
			return false;
		}
	}

    public NewsBlurResponse markStoriesAsRead(List<String> storyHashes) {
        ValueMultimap values = new ValueMultimap();
        for (String storyHash : storyHashes) {
            values.put(APIConstants.PARAMETER_STORY_HASH, storyHash);
        }
        APIResponse response = post(APIConstants.URL_MARK_STORIES_READ, values, false);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

	public NewsBlurResponse markStoryAsStarred(final String feedId, final String storyId) {
		final ValueMultimap values = new ValueMultimap();
		values.put(APIConstants.PARAMETER_FEEDID, feedId);
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		final APIResponse response = post(APIConstants.URL_MARK_STORY_AS_STARRED, values, false);
        return response.getResponse(gson, NewsBlurResponse.class);
	}

    public NewsBlurResponse markStoryAsUnread( String feedId, String storyId ) {
		final ValueMultimap values = new ValueMultimap();
		values.put(APIConstants.PARAMETER_FEEDID, feedId);
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		final APIResponse response = post(APIConstants.URL_MARK_STORY_AS_UNREAD, values, false);
        return response.getResponse(gson, NewsBlurResponse.class); 
    }

	public CategoriesResponse getCategories() {
		final APIResponse response = get(APIConstants.URL_CATEGORIES);
		if (!response.isError()) {
			CategoriesResponse categoriesResponse = (CategoriesResponse) response.getResponse(gson, CategoriesResponse.class);
            return categoriesResponse;
		} else {
			return null;
		}
	}

	public RegisterResponse signup(final String username, final String password, final String email) {
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERNAME, username);
		values.put(APIConstants.PARAMETER_PASSWORD, password);
		values.put(APIConstants.PARAMETER_EMAIL, email);
		final APIResponse response = post(APIConstants.URL_SIGNUP, values);
        RegisterResponse registerResponse = ((RegisterResponse) response.getResponse(gson, RegisterResponse.class));
		if (!response.isError()) {
			PrefsUtils.saveLogin(context, username, response.getCookie());

			CookieSyncManager.createInstance(context.getApplicationContext());
			CookieManager cookieManager = CookieManager.getInstance();

			cookieManager.setCookie(APIConstants.COOKIE_DOMAIN, response.getCookie());
			CookieSyncManager.getInstance().sync();
		}
        return registerResponse;
	}

	public ProfileResponse updateUserProfile() {
		final APIResponse response = get(APIConstants.URL_MY_PROFILE);
		if (!response.isError()) {
			ProfileResponse profileResponse = (ProfileResponse) response.getResponse(gson, ProfileResponse.class);
			PrefsUtils.saveUserDetails(context, profileResponse.user);
			return profileResponse;
		} else {
			return null;
		}
	}

	public StoriesResponse getStoriesForFeed(String feedId, String pageNumber, StoryOrder order, ReadFilter filter) {
		final ContentValues values = new ContentValues();
		Uri feedUri = Uri.parse(APIConstants.URL_FEED_STORIES).buildUpon().appendPath(feedId).build();
		values.put(APIConstants.PARAMETER_FEEDS, feedId);
		values.put(APIConstants.PARAMETER_PAGE_NUMBER, pageNumber);
		values.put(APIConstants.PARAMETER_ORDER, order.getParameterValue());
		values.put(APIConstants.PARAMETER_READ_FILTER, filter.getParameterValue());

		final APIResponse response = get(feedUri.toString(), values);
		Uri storyUri = FeedProvider.FEED_STORIES_URI.buildUpon().appendPath(feedId).build();

		if (!response.isError()) {
			if (TextUtils.equals(pageNumber, "1")) {
				contentResolver.delete(storyUri, null, null);
			}
			StoriesResponse storiesResponse = (StoriesResponse) response.getResponse(gson, StoriesResponse.class);

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
		final ValueMultimap values = new ValueMultimap();
		for (String feedId : feedIds) {
			values.put(APIConstants.PARAMETER_FEEDS, feedId);
		}
		if (!TextUtils.isEmpty(pageNumber)) {
			values.put(APIConstants.PARAMETER_PAGE_NUMBER, "" + pageNumber);
		}
		values.put(APIConstants.PARAMETER_ORDER, order.getParameterValue());
		values.put(APIConstants.PARAMETER_READ_FILTER, filter.getParameterValue());
		final APIResponse response = get(APIConstants.URL_RIVER_STORIES, values);

		StoriesResponse storiesResponse = (StoriesResponse) response.getResponse(gson, StoriesResponse.class);
		if (!response.isError()) {
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
		final ValueMultimap values = new ValueMultimap();
		if (!TextUtils.isEmpty(pageNumber)) {
			values.put(APIConstants.PARAMETER_PAGE_NUMBER, "" + pageNumber);
		}
		final APIResponse response = get(APIConstants.URL_STARRED_STORIES, values);

		StoriesResponse storiesResponse = (StoriesResponse) response.getResponse(gson, StoriesResponse.class);
		if (!response.isError()) {
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

	public SocialFeedResponse getSharedStoriesForFeeds(String[] feedIds, String pageNumber, StoryOrder order, ReadFilter filter) {
		final ValueMultimap values = new ValueMultimap();
		for (String feedId : feedIds) {
			values.put(APIConstants.PARAMETER_FEEDS, feedId);
		}
		if (!TextUtils.isEmpty(pageNumber)) {
			values.put(APIConstants.PARAMETER_PAGE_NUMBER, "" + pageNumber);
		}
		values.put(APIConstants.PARAMETER_ORDER, order.getParameterValue());
        values.put(APIConstants.PARAMETER_READ_FILTER, filter.getParameterValue());

		final APIResponse response = get(APIConstants.URL_SHARED_RIVER_STORIES, values);
		SocialFeedResponse storiesResponse = (SocialFeedResponse) response.getResponse(gson, SocialFeedResponse.class);
		if (!response.isError()) {

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

	public SocialFeedResponse getStoriesForSocialFeed(String userId, String username, String pageNumber, StoryOrder order, ReadFilter filter) {
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USER_ID, userId);
		values.put(APIConstants.PARAMETER_USERNAME, username);
		values.put(APIConstants.PARAMETER_ORDER, order.getParameterValue());
        values.put(APIConstants.PARAMETER_READ_FILTER, filter.getParameterValue());
		if (!TextUtils.isEmpty(pageNumber)) {
			values.put(APIConstants.PARAMETER_PAGE_NUMBER, "" + pageNumber);
		}
		Uri feedUri = Uri.parse(APIConstants.URL_SOCIALFEED_STORIES).buildUpon().appendPath(userId).appendPath(username).build();
		final APIResponse response = get(feedUri.toString(), values);
		SocialFeedResponse socialFeedResponse = (SocialFeedResponse) response.getResponse(gson, SocialFeedResponse.class);
		if (!response.isError()) {

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

            if (socialFeedResponse.feeds != null) {
                for (Feed feed : socialFeedResponse.feeds) {
                    contentResolver.insert(FeedProvider.FEEDS_URI, feed.getValues());
                }
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
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERID, userId);
		final APIResponse response = post(APIConstants.URL_FOLLOW, values);
		if (!response.isError()) {
			return true;
		} else {
			return false;
		}
	}

	public boolean unfollowUser(final String userId) {
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERID, userId);
		final APIResponse response = post(APIConstants.URL_UNFOLLOW, values);
		if (!response.isError()) {
			return true;
		} else {
			return false;
		}
	}

	public Boolean shareStory(final String storyId, final String feedId, final String comment, final String sourceUserId) {
		final ContentValues values = new ContentValues();
		if (!TextUtils.isEmpty(comment)) {
			values.put(APIConstants.PARAMETER_SHARE_COMMENT, comment);
		}
		if (!TextUtils.isEmpty(sourceUserId)) {
			values.put(APIConstants.PARAMETER_SHARE_SOURCEID, sourceUserId);
		}
		values.put(APIConstants.PARAMETER_FEEDID, feedId);
		values.put(APIConstants.PARAMETER_STORYID, storyId);

		final APIResponse response = post(APIConstants.URL_SHARE_STORY, values);
		if (!response.isError()) {
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
		
		final ContentValues params = new ContentValues();
		params.put( APIConstants.PARAMETER_UPDATE_COUNTS, (doUpdateCounts ? "true" : "false") );
		final APIResponse response = get(APIConstants.URL_FEEDS, params);

		// note: this response is complex enough, we have to do a custom parse in the FFR
        final FeedFolderResponse feedUpdate = new FeedFolderResponse(response.getResponseBody(), gson);

        // there is a rare issue with feeds that have no folder.  capture them for debug.
        List<String> debugFeedIds = new ArrayList<String>();
		
		if (!response.isError()) {

            // if the response says we aren't logged in, clear the DB and prompt for login. We test this
            // here, since this the first sync call we make on launch if we believe we are cookied.
            if (! feedUpdate.isAuthenticated) {
                PrefsUtils.logout(context);
                return false;
            }

            // this actually cleans out the feed, folder, and story tables
            contentResolver.delete(FeedProvider.FEEDS_URI, null, null);

            // data for the folder and folder-feed-mapping tables
            List<ContentValues> folderValues = new ArrayList<ContentValues>();
            List<ContentValues> ffmValues = new ArrayList<ContentValues>();
			for (final Entry<String, List<Long>> entry : feedUpdate.folders.entrySet()) {
				if (!TextUtils.isEmpty(entry.getKey())) {
					String folderName = entry.getKey().trim();
					if (!TextUtils.isEmpty(folderName)) {
						final ContentValues values = new ContentValues();
						values.put(DatabaseConstants.FOLDER_NAME, folderName);
						folderValues.add(values);
					}
	
					for (Long feedId : entry.getValue()) {
                        ContentValues values = new ContentValues(); 
                        values.put(DatabaseConstants.FEED_FOLDER_FEED_ID, feedId);
                        values.put(DatabaseConstants.FEED_FOLDER_FOLDER_NAME, folderName);
                        ffmValues.add(values);
                        // note all feeds that belong to some folder
                        debugFeedIds.add(Long.toString(feedId));
					}
				}
			}

            // data for the feeds table
			List<ContentValues> feedValues = new ArrayList<ContentValues>();
			for (String feedId : feedUpdate.feeds.keySet()) {
                // sanity-check that the returned feeds actually exist in a folder or at the root
                // if they do not, they should neither display nor count towards unread numbers
                if (debugFeedIds.contains(feedId)) {
                    feedValues.add(feedUpdate.feeds.get(feedId).getValues());
                } else {
                    Log.w(this.getClass().getName(), "Found and ignoring un-foldered feed: " + feedId );
                }
			}
			
			// data for the the social feeds table
            List<ContentValues> socialFeedValues = new ArrayList<ContentValues>();
			for (final SocialFeed feed : feedUpdate.socialFeeds) {
				socialFeedValues.add(feed.getValues());
			}
			
            bulkInsertList(FeedProvider.SOCIAL_FEEDS_URI, socialFeedValues);
            bulkInsertList(FeedProvider.FEEDS_URI, feedValues);
            bulkInsertList(FeedProvider.FOLDERS_URI, folderValues);
            bulkInsertList(FeedProvider.FEED_FOLDER_MAP_URI, ffmValues);

            // populate the starred stories count table
            int starredStoriesCount = feedUpdate.starredCount;
            ContentValues values = new ContentValues();
            values.put(DatabaseConstants.STARRED_STORY_COUNT_COUNT, starredStoriesCount);
            contentResolver.update(FeedProvider.STARRED_STORIES_COUNT_URI, values, null, null);

		}
		return true;
	}

	public NewsBlurResponse trainClassifier(String feedId, String key, int type, int action) {
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

		final APIResponse response = post(APIConstants.URL_CLASSIFIER_SAVE, values);
		return response.getResponse(gson, NewsBlurResponse.class);
	}

	public ProfileResponse getUser(String userId) {
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USER_ID, userId);
		final APIResponse response = get(APIConstants.URL_USER_PROFILE, values);
		if (!response.isError()) {
			ProfileResponse profileResponse = (ProfileResponse) response.getResponse(gson, ProfileResponse.class);
			return profileResponse;
		} else {
			return null;
		}
	}

	public void refreshFeedCounts() {
		final APIResponse response = get(APIConstants.URL_FEED_COUNTS);
		if (!response.isError()) {
			final FeedRefreshResponse feedCountUpdate = (FeedRefreshResponse) response.getResponse(gson, FeedRefreshResponse.class);
			for (String feedId : feedCountUpdate.feedCounts.keySet()) {
				Uri feedUri = FeedProvider.FEEDS_URI.buildUpon().appendPath(feedId).build();
                if (feedCountUpdate.feedCounts.get(feedId) != null) {
				    contentResolver.update(feedUri, feedCountUpdate.feedCounts.get(feedId).getValues(), null, null);
                }
			}

			for (String socialfeedId : feedCountUpdate.socialfeedCounts.keySet()) {
				String userId = socialfeedId.split(":")[1];
				Uri feedUri = FeedProvider.SOCIAL_FEEDS_URI.buildUpon().appendPath(userId).build();
                if (feedCountUpdate.socialfeedCounts.get(socialfeedId) != null) {
				    contentResolver.update(feedUri, feedCountUpdate.socialfeedCounts.get(socialfeedId).getValues(), null, null);
                }
			}
		}
	}

	public boolean favouriteComment(String storyId, String commentId, String feedId) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		values.put(APIConstants.PARAMETER_STORY_FEEDID, feedId);
		values.put(APIConstants.PARAMETER_COMMENT_USERID, commentId);
		final APIResponse response = post(APIConstants.URL_LIKE_COMMENT, values);
		return (!response.isError());
	}

	public Boolean unFavouriteComment(String storyId, String commentId, String feedId) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		values.put(APIConstants.PARAMETER_STORY_FEEDID, feedId);
		values.put(APIConstants.PARAMETER_COMMENT_USERID, commentId);
		final APIResponse response = post(APIConstants.URL_UNLIKE_COMMENT, values);
		return (!response.isError());
	}

	public boolean replyToComment(String storyId, String storyFeedId, String commentUserId, String reply) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		values.put(APIConstants.PARAMETER_STORY_FEEDID, storyFeedId);
		values.put(APIConstants.PARAMETER_COMMENT_USERID, commentUserId);
		values.put(APIConstants.PARAMETER_REPLY_TEXT, reply);
		final APIResponse response = post(APIConstants.URL_REPLY_TO, values);
		return (!response.isError());
	}

	public boolean addFeed(String feedUrl, String folderName) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_URL, feedUrl);
		if (!TextUtils.isEmpty(folderName)) {
			values.put(APIConstants.PARAMETER_FOLDER, folderName);
		}
		final APIResponse response = post(APIConstants.URL_ADD_FEED, values);
		return (!response.isError());
	}

	public FeedResult[] searchForFeed(String searchTerm) throws ServerErrorException {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_FEED_SEARCH_TERM, searchTerm);
		final APIResponse response = get(APIConstants.URL_FEED_AUTOCOMPLETE, values);

		if (!response.isError()) {
            return gson.fromJson(response.getResponseBody(), FeedResult[].class);
		} else {
			return null;
		}
	}

	public NewsBlurResponse deleteFeed(long feedId, String folderName) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_FEEDID, Long.toString(feedId));
		if ((!TextUtils.isEmpty(folderName)) && (!folderName.equals(AppConstants.ROOT_FOLDER))) {
			values.put(APIConstants.PARAMETER_IN_FOLDER, folderName);
		}
		APIResponse response = post(APIConstants.URL_DELETE_FEED, values);
		return response.getResponse(gson, NewsBlurResponse.class);
	}

    /* HTTP METHODS */
   
	private APIResponse get(final String urlString) {
        APIResponse response;
        int tryCount = 0;
        do {
            backoffSleep(tryCount++);
            response = get_single(urlString);
        } while ((response.isError()) && (tryCount < AppConstants.MAX_API_TRIES));
        return response;
    }
	private APIResponse get_single(final String urlString) {
		if (!NetworkUtils.isOnline(context)) {
			return new APIResponse(context);
		}
		try {
			URL url = new URL(urlString);
            Log.d(this.getClass().getName(), "API GET " + url );
			HttpURLConnection connection = (HttpURLConnection) url.openConnection();
			SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
			String cookie = preferences.getString(PrefConstants.PREF_COOKIE, null);
			if (cookie != null) {
				connection.setRequestProperty("Cookie", cookie);
			}
			return new APIResponse(context, url, connection);
		} catch (IOException e) {
			Log.e(this.getClass().getName(), "Error opening GET connection to " + urlString, e.getCause());
			return new APIResponse(context);
		} 
	}
	
	private APIResponse get(final String urlString, final ContentValues values) {
        List<String> parameters = new ArrayList<String>();
        for (Entry<String, Object> entry : values.valueSet()) {
            StringBuilder builder = new StringBuilder();
            builder.append((String) entry.getKey());
            builder.append("=");
            builder.append(URLEncoder.encode((String) entry.getValue()));
            parameters.add(builder.toString());
        }
        return this.get(urlString + "?" + TextUtils.join("&", parameters));
	}
	
	private APIResponse get(final String urlString, final ValueMultimap valueMap) {
        return this.get(urlString + "?" + valueMap.getParameterString());
	}

	private APIResponse post(String urlString, String postBodyString) {
        APIResponse response;
        int tryCount = 0;
        do {
            backoffSleep(tryCount++);
            response = post_single(urlString, postBodyString);
        } while ((response.isError()) && (tryCount < AppConstants.MAX_API_TRIES));
        return response;
    }

	private APIResponse post_single(String urlString, String postBodyString) {
		if (!NetworkUtils.isOnline(context)) {
			return new APIResponse(context);
		}
		try {
			URL url = new URL(urlString);
            Log.d(this.getClass().getName(), "API POST " + url );
            if (AppConstants.VERBOSE_LOG) {
                Log.d(this.getClass().getName(), "post body: " + postBodyString);
            }
			HttpURLConnection connection = (HttpURLConnection) url.openConnection();
			connection.setDoOutput(true);
			connection.setRequestMethod("POST");
			connection.setFixedLengthStreamingMode(postBodyString.getBytes().length);
			connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
			SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
			String cookie = preferences.getString(PrefConstants.PREF_COOKIE, null);
			if (cookie != null) {
				connection.setRequestProperty("Cookie", cookie);
			}
			PrintWriter printWriter = new PrintWriter(connection.getOutputStream());
			printWriter.print(postBodyString);
			printWriter.close();
			return new APIResponse(context, url, connection);
		} catch (IOException e) {
			Log.e(this.getClass().getName(), "Error opening POST connection to " + urlString + ": " + e.getCause(), e.getCause());
			return new APIResponse(context);
		} 
	}

	private APIResponse post(final String urlString, final ContentValues values) {
		List<String> parameters = new ArrayList<String>();
		for (Entry<String, Object> entry : values.valueSet()) {
			final StringBuilder builder = new StringBuilder();
			
			builder.append((String) entry.getKey());
			builder.append("=");
			try {
				builder.append(URLEncoder.encode((String) entry.getValue(), "UTF-8"));
			} catch (UnsupportedEncodingException e) {
				Log.e(this.getClass().getName(), e.getLocalizedMessage());
				return new APIResponse(context);
			}
			parameters.add(builder.toString());
		}
		final String parameterString = TextUtils.join("&", parameters);

        return this.post(urlString, parameterString);
	}
	
	private APIResponse post(final String urlString, final ValueMultimap valueMap, boolean jsonIfy) {
        String parameterString = jsonIfy ? valueMap.getJsonString() : valueMap.getParameterString();
        return this.post(urlString, parameterString);
	}

    /**
     * Pause for the sake of exponential retry-backoff as apropriate before the Nth call as counted
     * by the zero-indexed tryCount.
     */
    private void backoffSleep(int tryCount) {
        if (tryCount == 0) return;
        Log.i(this.getClass().getName(), "API call failed, pausing before retry number " + tryCount);
        try {
            // simply double the base sleep time for each subsequent try
            long factor = Math.round(Math.pow(2.0d, tryCount));
            Thread.sleep(AppConstants.API_BACKOFF_BASE_MILLIS * factor);
        } catch (InterruptedException ie) {
            Log.w(this.getClass().getName(), "Abandoning API backoff due to interrupt.");
        }
    }

    /**
     * Convenience method to call contentResolver.bulkInsert using a list rather than an array.
     */
    private int bulkInsertList(Uri uri, List<ContentValues> list) {
        if (list.size() > 0) {
            return contentResolver.bulkInsert(uri, list.toArray(new ContentValues[list.size()]));
        }
        return 0;
    }

}
