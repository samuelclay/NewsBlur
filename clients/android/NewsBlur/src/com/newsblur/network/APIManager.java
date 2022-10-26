package com.newsblur.network;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;

import android.content.ContentValues;
import android.content.Context;
import android.content.SharedPreferences;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.text.TextUtils;
import android.util.Log;

import com.google.gson.Gson;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.FeedResult;
import com.newsblur.domain.ValueMultimap;
import static com.newsblur.network.APIConstants.buildUrl;
import com.newsblur.network.domain.ActivitiesResponse;
import com.newsblur.network.domain.AddFeedResponse;
import com.newsblur.network.domain.CommentResponse;
import com.newsblur.network.domain.FeedFolderResponse;
import com.newsblur.network.domain.InteractionsResponse;
import com.newsblur.network.domain.LoginResponse;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.network.domain.ProfileResponse;
import com.newsblur.network.domain.RegisterResponse;
import com.newsblur.network.domain.StarredStoryHashesResponse;
import com.newsblur.network.domain.StoriesResponse;
import com.newsblur.network.domain.StoryChangesResponse;
import com.newsblur.network.domain.StoryTextResponse;
import com.newsblur.network.domain.UnreadCountResponse;
import com.newsblur.network.domain.UnreadStoryHashesResponse;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.NetworkUtils;
import com.newsblur.util.PrefConstants;
import com.newsblur.util.PrefsUtils;
import com.newsblur.util.ReadFilter;
import com.newsblur.util.StoryOrder;
import com.newsblur.widget.WidgetUtils;

import okhttp3.FormBody;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

public class APIManager {

	private final Context context;
	private final Gson gson;
	private final OkHttpClient httpClient;
    private String customUserAgent;

	public APIManager(final Context context, Gson gson, String customUserAgent, OkHttpClient httpClient) {
        APIConstants.setCustomServer(PrefsUtils.getCustomServer(context));
        this.context = context;
        this.gson = gson;
        this.customUserAgent = customUserAgent;
        this.httpClient = httpClient;
	}

	public LoginResponse login(final String username, final String password) {
        // This call should be pretty rare, but is expensive on the server side.  Log it
        // at an above-debug level so it will be noticed if it ever gets called too often.
        com.newsblur.util.Log.i(this.getClass().getName(), "calling login API");
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERNAME, username);
		values.put(APIConstants.PARAMETER_PASSWORD, password);
		final APIResponse response = post(buildUrl(APIConstants.PATH_LOGIN), values);
        LoginResponse loginResponse = response.getLoginResponse(gson);
		if (!response.isError()) {
			PrefsUtils.saveLogin(context, username, response.getCookie());
		} 
        return loginResponse;
    }

    public boolean loginAs(String username) {
        ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_USER, username);
        String urlString = buildUrl(APIConstants.PATH_LOGINAS) + "?" + builderGetParametersString(values);
        com.newsblur.util.Log.i(this.getClass().getName(), "doing superuser swap: " + urlString);
        // This API returns a redirect that means the call worked, but we do not want to follow it.  To
        // just get the cookie from the 302 and stop, we directly use a one-off OkHttpClient.
        Request.Builder requestBuilder = new Request.Builder().url(urlString);
        addCookieHeader(requestBuilder);
        OkHttpClient noredirHttpClient = new OkHttpClient.Builder()
                                         .followRedirects(false)
                                         .build();
        try {
            Response response = noredirHttpClient.newCall(requestBuilder.build()).execute();
            if (!response.isRedirect()) return false;
            String newCookie = response.header("Set-Cookie");
            PrefsUtils.saveLogin(context, username, newCookie);
        } catch (IOException ioe) {
            return false;
        }
        return true;
    }

	public boolean setAutoFollow(boolean autofollow) {
		ContentValues values = new ContentValues();
		values.put("autofollow_friends", autofollow ? "true" : "false");
		final APIResponse response = post(buildUrl(APIConstants.PATH_AUTOFOLLOW_PREF), values);
		return (!response.isError());
	}

	public NewsBlurResponse markFeedsAsRead(FeedSet fs, Long includeOlder, Long includeNewer) {
		ValueMultimap values = new ValueMultimap();

        if (fs.getSingleFeed() != null) {
            values.put(APIConstants.PARAMETER_FEEDID, fs.getSingleFeed());
        } else if (fs.getMultipleFeeds() != null) {
            for (String feedId : fs.getMultipleFeeds()) {
                // the API isn't supposed to care if the zero-id pseudo feed gets mentioned, but it seems to
                // error out for some users
                if (!feedId.equals("0")) {
                    values.put(APIConstants.PARAMETER_FEEDID, feedId);
                }
            }
        } else if (fs.getSingleSocialFeed() != null) {
            values.put(APIConstants.PARAMETER_FEEDID, APIConstants.VALUE_PREFIX_SOCIAL + fs.getSingleSocialFeed().getKey());
        } else if (fs.getMultipleSocialFeeds() != null) {
            for (Map.Entry<String,String> entry : fs.getMultipleSocialFeeds().entrySet()) {
                values.put(APIConstants.PARAMETER_FEEDID, APIConstants.VALUE_PREFIX_SOCIAL + entry.getKey());
            }
        } else if (fs.isAllNormal()) {
            // all stories uses a special API call
            return markAllAsRead();
        } else if (fs.isAllSocial()) {
            values.put(APIConstants.PARAMETER_FEEDID, APIConstants.VALUE_ALLSOCIAL);
        } else {
            throw new IllegalStateException("Asked to get stories for FeedSet of unknown type.");
        }

        if (includeOlder != null) {
            // the app uses  milliseconds but the API wants seconds
            long cut = includeOlder.longValue();
            values.put(APIConstants.PARAMETER_CUTOFF_TIME, Long.toString(cut/1000L));
            values.put(APIConstants.PARAMETER_DIRECTION, APIConstants.VALUE_OLDER);
        }
        if (includeNewer != null) {
            // the app uses  milliseconds but the API wants seconds
            long cut = includeNewer.longValue();
            values.put(APIConstants.PARAMETER_CUTOFF_TIME, Long.toString(cut/1000L));
            values.put(APIConstants.PARAMETER_DIRECTION, APIConstants.VALUE_NEWER);
        }

		APIResponse response = post(buildUrl(APIConstants.PATH_MARK_FEED_AS_READ), values);
        return response.getResponse(gson, NewsBlurResponse.class);
	}
	
	private NewsBlurResponse markAllAsRead() {
		ValueMultimap values = new ValueMultimap();
		values.put(APIConstants.PARAMETER_DAYS, "0");
		APIResponse response = post(buildUrl(APIConstants.PATH_MARK_ALL_AS_READ), values);
        return response.getResponse(gson, NewsBlurResponse.class);
	}

    public NewsBlurResponse markStoryAsRead(String storyHash) {
        ValueMultimap values = new ValueMultimap();
        values.put(APIConstants.PARAMETER_STORY_HASH, storyHash);
        APIResponse response = post(buildUrl(APIConstants.PATH_MARK_STORIES_READ), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

	public NewsBlurResponse markStoryAsStarred(String storyHash, List<String> userTags) {
		ValueMultimap values = new ValueMultimap();
		values.put(APIConstants.PARAMETER_STORY_HASH, storyHash);
        for (String tag : userTags) {
            values.put(APIConstants.PAREMETER_USER_TAGS, tag);
        }
		APIResponse response = post(buildUrl(APIConstants.PATH_MARK_STORY_AS_STARRED), values);
        return response.getResponse(gson, NewsBlurResponse.class);
	}
	
    public NewsBlurResponse markStoryAsUnstarred(String storyHash) {
		ValueMultimap values = new ValueMultimap();
		values.put(APIConstants.PARAMETER_STORY_HASH, storyHash);
		APIResponse response = post(buildUrl(APIConstants.PATH_MARK_STORY_AS_UNSTARRED), values);
        return response.getResponse(gson, NewsBlurResponse.class);
	}

    public NewsBlurResponse markStoryHashUnread(String hash) {
		final ValueMultimap values = new ValueMultimap();
        values.put(APIConstants.PARAMETER_STORY_HASH, hash);
        APIResponse response = post(buildUrl(APIConstants.PATH_MARK_STORY_HASH_UNREAD), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

	public RegisterResponse signup(final String username, final String password, final String email) {
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERNAME, username);
		values.put(APIConstants.PARAMETER_PASSWORD, password);
		values.put(APIConstants.PARAMETER_EMAIL, email);
		final APIResponse response = post(buildUrl(APIConstants.PATH_SIGNUP), values);
        RegisterResponse registerResponse = response.getRegisterResponse(gson);
		if (!response.isError()) {
			PrefsUtils.saveLogin(context, username, response.getCookie());
		}
        return registerResponse;
	}

	public ProfileResponse updateUserProfile() {
		final APIResponse response = get(buildUrl(APIConstants.PATH_MY_PROFILE));
		if (!response.isError()) {
			ProfileResponse profileResponse = (ProfileResponse) response.getResponse(gson, ProfileResponse.class);
			PrefsUtils.saveUserDetails(context, profileResponse.user);
			return profileResponse;
		} else {
			return null;
		}
	}

    public NewsBlurResponse moveFeedToFolders(String feedId, Set<String> toFolders, Set<String> inFolders) {
        ValueMultimap values = new ValueMultimap();
        for (String folder : toFolders) {
            if (folder.equals(AppConstants.ROOT_FOLDER)) folder = "";
            values.put(APIConstants.PARAMETER_TO_FOLDER, folder);
        }
        for (String folder : inFolders) {
            if (folder.equals(AppConstants.ROOT_FOLDER)) folder = "";
            values.put(APIConstants.PARAMETER_IN_FOLDERS, folder);
        }
        values.put(APIConstants.PARAMETER_FEEDID, feedId);
        APIResponse response = post(buildUrl(APIConstants.PATH_MOVE_FEED_TO_FOLDERS), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

    public UnreadCountResponse getFeedUnreadCounts(Set<String> apiIds) {
        ValueMultimap values = new ValueMultimap();
        for (String id : apiIds) {
            values.put(APIConstants.PARAMETER_FEEDID, id);
        }
        APIResponse response = get(buildUrl(APIConstants.PATH_FEED_UNREAD_COUNT), values);
        return (UnreadCountResponse) response.getResponse(gson, UnreadCountResponse.class);
    }

    public UnreadStoryHashesResponse getUnreadStoryHashes() {
		ValueMultimap values = new ValueMultimap();
        values.put(APIConstants.PARAMETER_INCLUDE_TIMESTAMPS, "1");
        APIResponse response = get(buildUrl(APIConstants.PATH_UNREAD_HASHES), values);
        return (UnreadStoryHashesResponse) response.getResponse(gson, UnreadStoryHashesResponse.class);
    }

    public StarredStoryHashesResponse getStarredStoryHashes() {
	    APIResponse response = get(buildUrl(APIConstants.PATH_STARRED_STORY_HASHES));
	    return response.getResponse(gson, StarredStoryHashesResponse.class);
    }

    public StoriesResponse getStoriesByHash(List<String> storyHashes) {
		ValueMultimap values = new ValueMultimap();
        for (String hash : storyHashes) {
            values.put(APIConstants.PARAMETER_H, hash);
        }
        values.put(APIConstants.PARAMETER_INCLUDE_HIDDEN, APIConstants.VALUE_TRUE);
        APIResponse response = get(buildUrl(APIConstants.PATH_RIVER_STORIES), values);
        return (StoriesResponse) response.getResponse(gson, StoriesResponse.class);
    }

    /**
     * Fetches stories for the given FeedSet, choosing the correct API and the right
     * request parameters as needed.
     */
    public StoriesResponse getStories(FeedSet fs, int pageNumber, StoryOrder order, ReadFilter filter) {
        Uri uri = null;
        ValueMultimap values = new ValueMultimap();
    
        // create the URI and populate request params depending on what kind of stories we want
        if (fs.isForWidget()) {
            uri = Uri.parse(buildUrl(APIConstants.PATH_RIVER_STORIES));
            for (String feedId : fs.getAllFeeds()) values.put(APIConstants.PARAMETER_FEEDS, feedId);
            values.put(APIConstants.PARAMETER_INCLUDE_HIDDEN, APIConstants.VALUE_FALSE);
            values.put(APIConstants.PARAMETER_INFREQUENT, APIConstants.VALUE_FALSE);
            values.put(APIConstants.PARAMETER_LIMIT, String.valueOf(WidgetUtils.STORIES_LIMIT));
        } else if (fs.getSingleFeed() != null) {
            uri = Uri.parse(buildUrl(APIConstants.PATH_FEED_STORIES)).buildUpon().appendPath(fs.getSingleFeed()).build();
            values.put(APIConstants.PARAMETER_FEEDS, fs.getSingleFeed());
            values.put(APIConstants.PARAMETER_INCLUDE_HIDDEN, APIConstants.VALUE_TRUE);
            if (fs.isFilterSaved()) values.put(APIConstants.PARAMETER_READ_FILTER, APIConstants.VALUE_STARRED);
        } else if (fs.getMultipleFeeds() != null) {
            uri = Uri.parse(buildUrl(APIConstants.PATH_RIVER_STORIES));
            for (String feedId : fs.getMultipleFeeds()) values.put(APIConstants.PARAMETER_FEEDS, feedId);
            values.put(APIConstants.PARAMETER_INCLUDE_HIDDEN, APIConstants.VALUE_TRUE);
            if (fs.isFilterSaved()) values.put(APIConstants.PARAMETER_READ_FILTER, APIConstants.VALUE_STARRED);
        } else if (fs.getSingleSocialFeed() != null) {
            String feedId = fs.getSingleSocialFeed().getKey();
            String username = fs.getSingleSocialFeed().getValue();
            uri = Uri.parse(buildUrl(APIConstants.PATH_SOCIALFEED_STORIES)).buildUpon().appendPath(feedId).appendPath(username).build();
            values.put(APIConstants.PARAMETER_USER_ID, feedId);
            values.put(APIConstants.PARAMETER_USERNAME, username);
        } else if (fs.getMultipleSocialFeeds() != null) {
            uri = Uri.parse(buildUrl(APIConstants.PATH_SHARED_RIVER_STORIES));
            for (Map.Entry<String,String> entry : fs.getMultipleSocialFeeds().entrySet()) {
                values.put(APIConstants.PARAMETER_FEEDS, entry.getKey());
            }
        } else if (fs.isInfrequent()) {
            uri = Uri.parse(buildUrl(APIConstants.PATH_RIVER_STORIES));
            values.put(APIConstants.PARAMETER_INCLUDE_HIDDEN, APIConstants.VALUE_TRUE);
            values.put(APIConstants.PARAMETER_INFREQUENT, Integer.toString(PrefsUtils.getInfrequentCutoff(context)));
        } else if (fs.isAllNormal()) {
            uri = Uri.parse(buildUrl(APIConstants.PATH_RIVER_STORIES));
            values.put(APIConstants.PARAMETER_INCLUDE_HIDDEN, APIConstants.VALUE_TRUE);
        } else if (fs.isAllSocial()) {
            uri = Uri.parse(buildUrl(APIConstants.PATH_SHARED_RIVER_STORIES));
        } else if (fs.isAllRead()) {
            uri = Uri.parse(buildUrl(APIConstants.PATH_READ_STORIES));
        } else if (fs.isAllSaved()) {
            uri = Uri.parse(buildUrl(APIConstants.PATH_STARRED_STORIES));
        } else if (fs.getSingleSavedTag() != null) {
            uri = Uri.parse(buildUrl(APIConstants.PATH_STARRED_STORIES));
            values.put(APIConstants.PARAMETER_TAG, fs.getSingleSavedTag());
        } else if (fs.isGlobalShared()) {
            uri = Uri.parse(buildUrl(APIConstants.PATH_SHARED_RIVER_STORIES));
            values.put(APIConstants.PARAMETER_GLOBAL_FEED, Boolean.TRUE.toString());
        } else {
            throw new IllegalStateException("Asked to get stories for FeedSet of unknown type.");
        }

		// request params common to most story sets
        values.put(APIConstants.PARAMETER_PAGE_NUMBER, Integer.toString(pageNumber));
        if (!(fs.isAllRead() || fs.isAllSaved() || fs.isFilterSaved())) {
		    values.put(APIConstants.PARAMETER_READ_FILTER, filter.getParameterValue());
        }
        if (!fs.isAllRead()) {
		    values.put(APIConstants.PARAMETER_ORDER, order.getParameterValue());
        }
        if (fs.getSearchQuery() != null) {
            values.put(APIConstants.PARAMETER_QUERY, fs.getSearchQuery());
        }

		APIResponse response = get(uri.toString(), values);
        return (StoriesResponse) response.getResponse(gson, StoriesResponse.class);
    }

	public boolean followUser(final String userId) {
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERID, userId);
		final APIResponse response = post(buildUrl(APIConstants.PATH_FOLLOW), values);
		if (!response.isError()) {
			return true;
		} else {
			return false;
		}
	}

	public boolean unfollowUser(final String userId) {
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USERID, userId);
		final APIResponse response = post(buildUrl(APIConstants.PATH_UNFOLLOW), values);
		if (!response.isError()) {
			return true;
		} else {
			return false;
		}
	}

	public APIResponse saveExternalStory(@NonNull String storyTitle, @NonNull String storyUrl) {
        ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_TITLE, storyTitle);
        values.put(APIConstants.PARAMETER_STORY_URL, storyUrl);

        return post(buildUrl(APIConstants.PATH_SAVE_EXTERNAL_STORY), values);
    }

	public APIResponse shareExternalStory(@NonNull String storyTitle, @NonNull String storyUrl, @NonNull String shareComments) {
        ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_TITLE, storyTitle);
        values.put(APIConstants.PARAMETER_STORY_URL, storyUrl);
        values.put(APIConstants.PARAMETER_SHARE_COMMENT, shareComments);

        return post(buildUrl(APIConstants.PATH_SHARE_EXTERNAL_STORY), values);
    }

    public StoriesResponse shareStory(String storyId, String feedId, String comment, String sourceUserId) {
        ContentValues values = new ContentValues();
        if (!TextUtils.isEmpty(comment)) {
            values.put(APIConstants.PARAMETER_SHARE_COMMENT, comment);
        }
        if (!TextUtils.isEmpty(sourceUserId)) {
            values.put(APIConstants.PARAMETER_SHARE_SOURCEID, sourceUserId);
        }
        values.put(APIConstants.PARAMETER_FEEDID, feedId);
        values.put(APIConstants.PARAMETER_STORYID, storyId);

        APIResponse response = post(buildUrl(APIConstants.PATH_SHARE_STORY), values);
        // this call returns a new copy of the story with all fields updated and some metadata
        return (StoriesResponse) response.getResponse(gson, StoriesResponse.class);
    }

    public StoriesResponse unshareStory(String storyId, String feedId) {
        ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_FEEDID, feedId);
        values.put(APIConstants.PARAMETER_STORYID, storyId);

        APIResponse response = post(buildUrl(APIConstants.PATH_UNSHARE_STORY), values);
        // this call returns a new copy of the story with all fields updated and some metadata
        return (StoriesResponse) response.getResponse(gson, StoriesResponse.class);
    }

	/**
     * Fetch the list of feeds/folders/socials from the backend.
     * 
     * @param doUpdateCounts forces a refresh of unread counts.  This has a high latency
     *        cost and should not be set if the call is being used to display the UI for
     *        the first time, in which case it is more appropriate to make a separate,
     *        additional call to refreshFeedCounts().
     */
    public FeedFolderResponse getFolderFeedMapping(boolean doUpdateCounts) {
		ContentValues params = new ContentValues();
		params.put(APIConstants.PARAMETER_UPDATE_COUNTS, (doUpdateCounts ? "true" : "false"));
		APIResponse response = get(buildUrl(APIConstants.PATH_FEEDS), params);

		if (response.isError()) {
            // we can't use the magic polymorphism of NewsBlurResponse because this result uses
            // a custom parser below. let the caller know the action failed.
            return null;
        }

		// note: this response is complex enough, we have to do a custom parse in the FFR
        FeedFolderResponse result = new FeedFolderResponse(response.getResponseBody(), gson);
        // bind a litle extra instrumentation to this response, since it powers the feedback link
        result.connTime = response.connectTime;
        result.readTime = response.readTime;
        return result;
	}

    public NewsBlurResponse updateFeedIntel(String feedId, Classifier classifier) {
        ValueMultimap values = classifier.getAPITuples();
        values.put(APIConstants.PARAMETER_FEEDID, feedId);
		APIResponse response = post(buildUrl(APIConstants.PATH_CLASSIFIER_SAVE), values);
		return response.getResponse(gson, NewsBlurResponse.class);
	}

	public ProfileResponse getUser(String userId) {
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_USER_ID, userId);
		final APIResponse response = get(buildUrl(APIConstants.PATH_USER_PROFILE), values);
		if (!response.isError()) {
			ProfileResponse profileResponse = (ProfileResponse) response.getResponse(gson, ProfileResponse.class);
			return profileResponse;
		} else {
			return null;
		}
	}

    public ActivitiesResponse getActivities(String userId, int pageNumber) {
        final ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_USER_ID, userId);
        values.put(APIConstants.PARAMETER_LIMIT, "10");
        values.put(APIConstants.PARAMETER_PAGE_NUMBER, Integer.toString(pageNumber));
        final APIResponse response = get(buildUrl(APIConstants.PATH_USER_ACTIVITIES), values);
        if (!response.isError()) {
            ActivitiesResponse activitiesResponse = (ActivitiesResponse) response.getResponse(gson, ActivitiesResponse.class);
            return activitiesResponse;
        } else {
            return null;
        }
    }

    public InteractionsResponse getInteractions(String userId, int pageNumber) {
        final ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_USER_ID, userId);
        values.put(APIConstants.PARAMETER_LIMIT, "10");
        values.put(APIConstants.PARAMETER_PAGE_NUMBER, Integer.toString(pageNumber));
        final APIResponse response = get(buildUrl(APIConstants.PATH_USER_INTERACTIONS), values);
        if (!response.isError()) {
            InteractionsResponse interactionsResponse = (InteractionsResponse) response.getResponse(gson, InteractionsResponse.class);
            return interactionsResponse;
        } else {
            return null;
        }
    }

	public StoryTextResponse getStoryText(String feedId, String storyId) {
		final ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_FEEDID, feedId);
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		final APIResponse response = get(buildUrl(APIConstants.PATH_STORY_TEXT), values);
		if (!response.isError()) {
			StoryTextResponse storyTextResponse = (StoryTextResponse) response.getResponse(gson, StoryTextResponse.class);
			return storyTextResponse;
		} else {
			return null;
		}
	}

	public StoryChangesResponse getStoryChanges(String storyHash, boolean showChanges) {
        final ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_STORY_HASH, storyHash);
        values.put(APIConstants.PARAMETER_SHOW_CHANGES, showChanges ? "true" : "false");
        final APIResponse response = get(buildUrl(APIConstants.PATH_STORY_CHANGES), values);
        return response.getResponse(gson, StoryChangesResponse.class);
    }

	public NewsBlurResponse favouriteComment(String storyId, String commentUserId, String feedId) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		values.put(APIConstants.PARAMETER_STORY_FEEDID, feedId);
		values.put(APIConstants.PARAMETER_COMMENT_USERID, commentUserId);
		APIResponse response = post(buildUrl(APIConstants.PATH_LIKE_COMMENT), values);
        return response.getResponse(gson, NewsBlurResponse.class);
	}

	public NewsBlurResponse unFavouriteComment(String storyId, String commentUserId, String feedId) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		values.put(APIConstants.PARAMETER_STORY_FEEDID, feedId);
		values.put(APIConstants.PARAMETER_COMMENT_USERID, commentUserId);
		APIResponse response = post(buildUrl(APIConstants.PATH_UNLIKE_COMMENT), values);
        return response.getResponse(gson, NewsBlurResponse.class);
	}

	public CommentResponse replyToComment(String storyId, String storyFeedId, String commentUserId, String reply) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		values.put(APIConstants.PARAMETER_STORY_FEEDID, storyFeedId);
		values.put(APIConstants.PARAMETER_COMMENT_USERID, commentUserId);
		values.put(APIConstants.PARAMETER_REPLY_TEXT, reply);
		APIResponse response = post(buildUrl(APIConstants.PATH_REPLY_TO), values);
        // this call returns a new copy of the comment with all fields updated
        return (CommentResponse) response.getResponse(gson, CommentResponse.class);
	}

	public CommentResponse editReply(String storyId, String storyFeedId, String commentUserId, String replyId, String reply) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		values.put(APIConstants.PARAMETER_STORY_FEEDID, storyFeedId);
		values.put(APIConstants.PARAMETER_COMMENT_USERID, commentUserId);
		values.put(APIConstants.PARAMETER_REPLY_ID, replyId);
		values.put(APIConstants.PARAMETER_REPLY_TEXT, reply);
		APIResponse response = post(buildUrl(APIConstants.PATH_EDIT_REPLY), values);
        // this call returns a new copy of the comment with all fields updated
        return (CommentResponse) response.getResponse(gson, CommentResponse.class);
	}

	public CommentResponse deleteReply(String storyId, String storyFeedId, String commentUserId, String replyId) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_STORYID, storyId);
		values.put(APIConstants.PARAMETER_STORY_FEEDID, storyFeedId);
		values.put(APIConstants.PARAMETER_COMMENT_USERID, commentUserId);
		values.put(APIConstants.PARAMETER_REPLY_ID, replyId);
		APIResponse response = post(buildUrl(APIConstants.PATH_DELETE_REPLY), values);
        // this call returns a new copy of the comment with all fields updated
        return (CommentResponse) response.getResponse(gson, CommentResponse.class);
	}

	public NewsBlurResponse addFolder(String folderName) {
        ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_FOLDER, folderName);
        APIResponse response = post(buildUrl(APIConstants.PATH_ADD_FOLDER), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

	public AddFeedResponse addFeed(String feedUrl, @Nullable String folderName) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_URL, feedUrl);
		if (!TextUtils.isEmpty(folderName) && !folderName.equals(AppConstants.ROOT_FOLDER)) {
		    values.put(APIConstants.PARAMETER_FOLDER, folderName);
        }
		APIResponse response = post(buildUrl(APIConstants.PATH_ADD_FEED), values);
		return response.getResponse(gson, AddFeedResponse.class);
	}

    @Nullable
	public FeedResult[] searchForFeed(String searchTerm) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_FEED_SEARCH_TERM, searchTerm);
		final APIResponse response = get(buildUrl(APIConstants.PATH_FEED_AUTOCOMPLETE), values);

		if (!response.isError()) {
            return gson.fromJson(response.getResponseBody(), FeedResult[].class);
		} else {
			return null;
		}
	}

	public NewsBlurResponse deleteFeed(String feedId, String folderName) {
		ContentValues values = new ContentValues();
		values.put(APIConstants.PARAMETER_FEEDID, feedId);
		if ((!TextUtils.isEmpty(folderName)) && (!folderName.equals(AppConstants.ROOT_FOLDER))) {
			values.put(APIConstants.PARAMETER_IN_FOLDER, folderName);
		}
		APIResponse response = post(buildUrl(APIConstants.PATH_DELETE_FEED), values);
		return response.getResponse(gson, NewsBlurResponse.class);
	}

	public NewsBlurResponse deleteFolder(String folderName, String inFolder) {
        ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_FOLDER_TO_DELETE, folderName);
        values.put(APIConstants.PARAMETER_IN_FOLDER, inFolder);
        APIResponse response = post(buildUrl(APIConstants.PATH_DELETE_FOLDER), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

	public NewsBlurResponse deleteSearch(String feedId, String query) {
        ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_FEEDID, feedId);
        values.put(APIConstants.PARAMETER_QUERY, query);
        APIResponse response = post(buildUrl(APIConstants.PATH_DELETE_SEARCH), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

    public NewsBlurResponse saveSearch(String feedId, String query) {
        ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_FEEDID, feedId);
        values.put(APIConstants.PARAMETER_QUERY, query);
        APIResponse response = post(buildUrl(APIConstants.PATH_SAVE_SEARCH), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

    public NewsBlurResponse saveFeedChooser(Set<String> feeds) {
        ValueMultimap values = new ValueMultimap();
        for (String feed : feeds) {
            values.put(APIConstants.PARAMETER_APPROVED_FEEDS, feed);
        }
        APIResponse response = post(buildUrl(APIConstants.PATH_SAVE_FEED_CHOOSER), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

    public NewsBlurResponse updateFeedNotifications(String feedId, List<String> notifyTypes, String notifyFilter) {
        ValueMultimap values = new ValueMultimap();
        values.put(APIConstants.PARAMETER_FEEDID, feedId);
        for (String type : notifyTypes) {
            values.put(APIConstants.PARAMETER_NOTIFICATION_TYPES, type);
        }
        if (notifyFilter != null )
            values.put(APIConstants.PARAMETER_NOTIFICATION_FILTER, notifyFilter);
        APIResponse response = post(buildUrl(APIConstants.PATH_SET_NOTIFICATIONS), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

    public NewsBlurResponse instaFetch(String feedId) {
        ValueMultimap values = new ValueMultimap();
        values.put(APIConstants.PARAMETER_FEEDID, feedId);
        // this param appears fixed and mandatory for the call to succeed
        values.put(APIConstants.PARAMETER_RESET_FETCH, APIConstants.VALUE_FALSE);
        APIResponse response = post(buildUrl(APIConstants.PATH_INSTA_FETCH), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

    public NewsBlurResponse renameFeed(String feedId, String newFeedName) {
        ValueMultimap values = new ValueMultimap();
        values.put(APIConstants.PARAMETER_FEEDID, feedId);
        values.put(APIConstants.PARAMETER_FEEDTITLE, newFeedName);
        APIResponse response = post(buildUrl(APIConstants.PATH_RENAME_FEED), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

    public NewsBlurResponse renameFolder(String folderName, String newFolderName, String inFolder) {
        ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_FOLDER_TO_RENAME, folderName);
        values.put(APIConstants.PARAMETER_NEW_FOLDER_NAME, newFolderName);
        values.put(APIConstants.PARAMETER_IN_FOLDER, inFolder);
        APIResponse response = post(buildUrl(APIConstants.PATH_RENAME_FOLDER), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

    public NewsBlurResponse saveReceipt(String orderId, String productId) {
        ContentValues values = new ContentValues();
        values.put(APIConstants.PARAMETER_ORDER_ID, orderId);
        values.put(APIConstants.PARAMETER_PRODUCT_ID, productId);
        APIResponse response = post(buildUrl(APIConstants.PATH_SAVE_RECEIPT), values);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

    public NewsBlurResponse importOpml(RequestBody requestBody) {
        APIResponse response = post(buildUrl(APIConstants.PATH_IMPORT_OPML), requestBody);
        return response.getResponse(gson, NewsBlurResponse.class);
    }

    public void updateCustomUserAgent(String customUserAgent) {
        this.customUserAgent = customUserAgent;
    }

    /* HTTP METHODS */
   
	private APIResponse get(final String urlString) {
        APIResponse response;
        int tryCount = 0;
        do {
            backoffSleep(tryCount++);
            response = get_single(urlString, HttpURLConnection.HTTP_OK);
        } while ((response.isError()) && (tryCount < AppConstants.MAX_API_TRIES));
        return response;
    }

	private APIResponse get_single(final String urlString, int expectedReturnCode) {
		if (!NetworkUtils.isOnline(context)) {
			return new APIResponse(context);
		}

		Request.Builder requestBuilder = new Request.Builder().url(urlString);
		addCookieHeader(requestBuilder);
		requestBuilder.header("User-Agent", this.customUserAgent);

		return new APIResponse(context, httpClient, requestBuilder.build(), expectedReturnCode);
	}

	private void addCookieHeader(Request.Builder requestBuilder) {
		SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		String cookie = preferences.getString(PrefConstants.PREF_COOKIE, null);
		if (cookie != null) {
			requestBuilder.header("Cookie", cookie);
		}
	}

	private APIResponse get(final String urlString, final ContentValues values) {
        return this.get(urlString + "?" + builderGetParametersString(values));
	}

    private String builderGetParametersString(ContentValues values) {
        List<String> parameters = new ArrayList<String>();
        for (Entry<String, Object> entry : values.valueSet()) {
            StringBuilder builder = new StringBuilder();
            builder.append((String) entry.getKey());
            builder.append("=");
            builder.append(NetworkUtils.encodeURL((String) entry.getValue()));
            parameters.add(builder.toString());
        }
        return TextUtils.join("&", parameters);
    }
	
	private APIResponse get(final String urlString, final ValueMultimap valueMap) {
        return this.get(urlString + "?" + valueMap.getParameterString());
	}

	private APIResponse post(String urlString, RequestBody formBody) {
        APIResponse response;
        int tryCount = 0;
        do {
            backoffSleep(tryCount++);
            response = post_single(urlString, formBody);
        } while ((response.isError()) && (tryCount < AppConstants.MAX_API_TRIES));
        return response;
    }

	private APIResponse post_single(String urlString, RequestBody formBody) {
		if (!NetworkUtils.isOnline(context)) {
			return new APIResponse(context);
		}

		if (AppConstants.VERBOSE_LOG_NET) {
			Log.d(this.getClass().getName(), "API POST " + urlString);
            String body = "";
            try {
                okio.Buffer buffer = new okio.Buffer();
                formBody.writeTo(buffer);
                body = buffer.readUtf8();
            } catch (Exception e) {
                ; // this is debug code, do not raise
            }
			Log.d(this.getClass().getName(), "post body: " + body);
		}

		Request.Builder requestBuilder = new Request.Builder().url(urlString);
		addCookieHeader(requestBuilder);
		requestBuilder.post(formBody);

		return new APIResponse(context, httpClient, requestBuilder.build());
	}

	private APIResponse post(final String urlString, final ContentValues values) {
		FormBody.Builder formEncodingBuilder = new FormBody.Builder();
		for (Entry<String, Object> entry : values.valueSet()) {
			formEncodingBuilder.add(entry.getKey(), (String)entry.getValue());
		}
        return this.post(urlString, formEncodingBuilder.build());
	}
	
	private APIResponse post(final String urlString, final ValueMultimap valueMap) {
        return this.post(urlString, valueMap.asFormEncodedRequestBody());
	}

    /**
     * Pause for the sake of exponential retry-backoff as apropriate before the Nth call as counted
     * by the zero-indexed tryCount.
     */
    private void backoffSleep(int tryCount) {
        if (tryCount == 0) return;
        com.newsblur.util.Log.i(this.getClass().getName(), "API call failed, pausing before retry number " + tryCount);
        try {
            // simply double the base sleep time for each subsequent try
            long factor = Math.round(Math.pow(2.0d, tryCount));
            Thread.sleep(AppConstants.API_BACKOFF_BASE_MILLIS * factor);
        } catch (InterruptedException ie) {
            com.newsblur.util.Log.w(this.getClass().getName(), "Abandoning API backoff due to interrupt.");
        }
    }
}
