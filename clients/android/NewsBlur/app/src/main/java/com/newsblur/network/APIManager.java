package com.newsblur.network;

import java.net.HttpURLConnection;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;

import android.content.ContentValues;
import android.content.Context;
import android.content.SharedPreferences;

import androidx.annotation.Nullable;
import android.text.TextUtils;
import android.util.Log;

import com.google.gson.Gson;
import com.newsblur.di.ApiOkHttpClient;
import com.newsblur.domain.Classifier;
import com.newsblur.domain.FeedResult;
import com.newsblur.domain.ValueMultimap;
import static com.newsblur.network.APIConstants.buildUrl;
import com.newsblur.network.domain.AddFeedResponse;
import com.newsblur.network.domain.FeedFolderResponse;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.network.domain.UnreadCountResponse;
import com.newsblur.preference.PrefsRepo;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedSet;
import com.newsblur.util.NetworkUtils;
import com.newsblur.util.PrefConstants;

import okhttp3.FormBody;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;

public class APIManager {

	private final Context context;
	private final Gson gson;
    @ApiOkHttpClient
	private final OkHttpClient apiOkHttpClient;
    private String customUserAgent;

	public APIManager(
            final Context context,
            Gson gson,
            String customUserAgent,
            @ApiOkHttpClient OkHttpClient apiOkHttpClient,
            PrefsRepo prefsRepo
    ) {
        APIConstants.setCustomServer(prefsRepo.getCustomServer());
        this.context = context;
        this.gson = gson;
        this.customUserAgent = customUserAgent;
        this.apiOkHttpClient = apiOkHttpClient;
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

    public UnreadCountResponse getFeedUnreadCounts(Set<String> apiIds) {
        ValueMultimap values = new ValueMultimap();
        for (String id : apiIds) {
            values.put(APIConstants.PARAMETER_FEEDID, id);
        }
        APIResponse response = get(buildUrl(APIConstants.PATH_FEED_UNREAD_COUNT), values);
        return response.getResponse(gson, UnreadCountResponse.class);
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

    APIResponse get(final String urlString) {
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
			return new APIResponse();
		}

		Request.Builder requestBuilder = new Request.Builder().url(urlString);
		addCookieHeader(requestBuilder);
		requestBuilder.header("User-Agent", this.customUserAgent);

		return new APIResponse(apiOkHttpClient, requestBuilder.build(), expectedReturnCode);
	}

    void addCookieHeader(Request.Builder requestBuilder) {
		SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
		String cookie = preferences.getString(PrefConstants.PREF_COOKIE, null);
		if (cookie != null) {
			requestBuilder.header("Cookie", cookie);
		}
	}

    APIResponse get(final String urlString, final ContentValues values) {
        return this.get(urlString + "?" + builderGetParametersString(values));
	}

    String builderGetParametersString(ContentValues values) {
        List<String> parameters = new ArrayList<>();
        for (Entry<String, Object> entry : values.valueSet()) {
            StringBuilder builder = new StringBuilder();
            builder.append(entry.getKey());
            builder.append("=");
            builder.append(NetworkUtils.encodeURL((String) entry.getValue()));
            parameters.add(builder.toString());
        }
        return TextUtils.join("&", parameters);
    }

    APIResponse get(final String urlString, final ValueMultimap valueMap) {
        return this.get(urlString + "?" + valueMap.getParameterString());
	}

    APIResponse post(String urlString, RequestBody formBody) {
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
			return new APIResponse();
		}

		if (AppConstants.VERBOSE_LOG_NET) {
			Log.d(this.getClass().getName(), "API POST " + urlString);
            String body = "";
            try {
                okio.Buffer buffer = new okio.Buffer();
                formBody.writeTo(buffer);
                body = buffer.readUtf8();
            } catch (Exception e) {
                // this is debug code, do not raise
            }
			Log.d(this.getClass().getName(), "post body: " + body);
		}

		Request.Builder requestBuilder = new Request.Builder().url(urlString);
		addCookieHeader(requestBuilder);
		requestBuilder.post(formBody);

		return new APIResponse(apiOkHttpClient, requestBuilder.build());
	}

    APIResponse post(final String urlString, final ContentValues values) {
		FormBody.Builder formEncodingBuilder = new FormBody.Builder();
		for (Entry<String, Object> entry : values.valueSet()) {
			formEncodingBuilder.add(entry.getKey(), (String)entry.getValue());
		}
        return this.post(urlString, formEncodingBuilder.build());
	}

    APIResponse post(final String urlString, final ValueMultimap valueMap) {
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
