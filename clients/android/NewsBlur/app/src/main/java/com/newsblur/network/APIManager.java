package com.newsblur.network;

import static com.newsblur.network.APIConstants.buildUrl;

import android.content.ContentValues;
import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;
import android.util.Log;

import com.google.gson.Gson;
import com.newsblur.di.ApiOkHttpClient;
import com.newsblur.domain.ValueMultimap;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.preference.PrefsRepo;
import com.newsblur.util.AppConstants;
import com.newsblur.util.NetworkUtils;
import com.newsblur.util.PrefConstants;

import java.net.HttpURLConnection;
import java.util.ArrayList;
import java.util.List;
import java.util.Map.Entry;

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

    APIResponse get_single(final String urlString, int expectedReturnCode) {
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
            formEncodingBuilder.add(entry.getKey(), (String) entry.getValue());
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
