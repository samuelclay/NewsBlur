package com.newsblur.network;

import java.io.IOException;

import android.content.Context;
import android.text.TextUtils;
import android.util.Log;

import com.google.gson.Gson;
import org.apache.http.HttpStatus;

import com.newsblur.R;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.util.AppConstants;
import com.squareup.okhttp.OkHttpClient;
import com.squareup.okhttp.Request;
import com.squareup.okhttp.Response;

/**
 * A JSON-encoded response from the API servers.  This class encodes the possible outcomes of
 * an attempted API call, including total failure, online failures, and successful responses.
 * In the latter case, the GSON reader used to look for errors is left open so that the expected
 * response can be read.  Instances of this class should be closed after use.
 */
public class APIResponse {
	
    private boolean isError;
    private String errorMessage;
	private String cookie;
    private String responseBody;
    public long connectTime;
    public long readTime;

    /**
     * Construct an online response.  Will test the response for errors and extract all the
     * info we might need.
     */
    public APIResponse(Context context, OkHttpClient httpClient, Request request) {
        this(context, httpClient, request, HttpStatus.SC_OK);
    }

    /**
     * Construct an online response.  Will test the response for errors and extract all the
     * info we might need.
     */
    public APIResponse(Context context, OkHttpClient httpClient, Request request, int expectedReturnCode) {

        this.errorMessage = context.getResources().getString(R.string.error_unset_message);

        try {
            long startTime = System.currentTimeMillis();
            Response response = httpClient.newCall(request).execute();
            connectTime = System.currentTimeMillis() - startTime;
            if (response.isSuccessful()) {

                if (response.code() != expectedReturnCode) {
                    Log.e(this.getClass().getName(), "API returned error code " + response.code() + " calling " + request.urlString() + ". Expected " + expectedReturnCode);
                    this.isError = true;
                    this.errorMessage = context.getResources().getString(R.string.error_http_connection);
                    return;
                }

                this.cookie = response.header("Set-Cookie");

                try {
                    startTime = System.currentTimeMillis();
                    this.responseBody = response.body().string();
                    readTime = System.currentTimeMillis() - startTime;
                } catch (Exception e) {
                    Log.e(this.getClass().getName(), e.getClass().getName() + " (" + e.getMessage() + ") reading " + request.urlString(), e);
                    this.isError = true;
                    this.errorMessage = context.getResources().getString(R.string.error_read_connection);
                    return;
                }

                if (AppConstants.VERBOSE_LOG_NET) {
                    // the default kernel truncates log lines. split by something we probably have, like a json delim
                    if (responseBody.length() < 2048) {
                        Log.d(this.getClass().getName(), "API response: \n" + this.responseBody);
                    } else {
                        Log.d(this.getClass().getName(), "API response: ");
                        for (String s : TextUtils.split(responseBody, "\\}")) {
                            Log.d(this.getClass().getName(), s + "}");
                        }
                    }
                }

                if (AppConstants.VERBOSE_LOG_NET) {
                    Log.d(this.getClass().getName(), String.format("called %s in %dms and %dms to read %dB", request.urlString(), connectTime, readTime, responseBody.length()));
                }

            } else {
                Log.e(this.getClass().getName(), "API call unsuccessful, error code" + response.code());
                this.isError = true;
                this.errorMessage = context.getResources().getString(R.string.error_http_connection);
                return;
            }

        } catch (IOException ioe) {
            Log.e(this.getClass().getName(), "Error (" + ioe.getMessage() + ") calling " + request.urlString(), ioe);
            this.isError = true;
            this.errorMessage = context.getResources().getString(R.string.error_read_connection);
            return;
        }
    }

    /**
     * Construct and empty/offline response.  Signals that the call was not made.
     */
    public APIResponse(Context context) {
        this.isError = true;
        this.errorMessage = context.getResources().getString(R.string.error_offline);
    }

    public boolean isError() {
        return this.isError;
    }

    public String getErrorMessage() {
        return this.errorMessage;
    }

    /**
     * Get the response object from this call.  A specific subclass of NewsBlurResponse
     * may be used for calls that return data, or the parent class may be used if no
     * return data are expected.
     */
    @SuppressWarnings("unchecked")
    public <T extends NewsBlurResponse> T getResponse(Gson gson, Class<T> classOfT) {
        if (this.isError) {
            // if we encountered an error, make a generic response type and populate
            // it's message field
            try {
                T response = classOfT.newInstance();
                response.message = this.errorMessage;
                response.isProtocolError = true;
                return ((T) response);
            } catch (Exception e) {
                // this should never fail unless the constructor of the base response bean fails
                Log.wtf(this.getClass().getName(), "Failed to load class: " + classOfT);
                return null;
            }
        } else {
            // otherwise, parse the response as the expected class and defer error detection
            // to the NewsBlurResponse parent class
            T response = gson.fromJson(this.responseBody, classOfT);
            response.readTime = readTime;
            return response;
        }
    }

    public NewsBlurResponse getResponse(Gson gson) {
        return getResponse(gson, NewsBlurResponse.class);
    }

    public String getResponseBody() {
        return this.responseBody;
    }

    public String getCookie() {
        return this.cookie;
    }

}
