package com.newsblur.network;

import java.io.IOException;
import java.net.HttpURLConnection;

import android.content.Context;
import android.text.TextUtils;
import android.util.Log;

import com.google.gson.Gson;

import com.newsblur.network.domain.LoginResponse;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.network.domain.RegisterResponse;
import com.newsblur.util.AppConstants;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;

/**
 * A JSON-encoded response from the API servers.  This class encodes the possible outcomes of
 * an attempted API call, including total failure, online failures, and successful responses.
 * In the latter case, the GSON reader used to look for errors is left open so that the expected
 * response can be read.
 */
public class APIResponse {
	
    private boolean isError;
    private int responseCode;
	private String cookie;
    private String responseBody;
    public long connectTime;
    public long readTime;

    /**
     * Construct an online response.  Will test the response for errors and extract all the
     * info we might need.
     */
    public APIResponse(Context context, OkHttpClient httpClient, Request request) {
        this(context, httpClient, request, HttpURLConnection.HTTP_OK);
    }

    /**
     * Construct an online response.  Will test the response for errors and extract all the
     * info we might need.
     */
    public APIResponse(Context context, OkHttpClient httpClient, Request request, int expectedReturnCode) {

        try {
            long startTime = System.currentTimeMillis();
            Response response = httpClient.newCall(request).execute();
            connectTime = System.currentTimeMillis() - startTime;
            this.responseCode = response.code();

            if (responseCode != expectedReturnCode) {
                Log.e(this.getClass().getName(), "API returned error code " + response.code() + " calling " + request.url().toString() + " - expected " + expectedReturnCode);
                this.isError = true;
                return;
            }

            this.cookie = response.header("Set-Cookie");

            try {
                startTime = System.currentTimeMillis();
                this.responseBody = response.body().string();
                readTime = System.currentTimeMillis() - startTime;
            } catch (Exception e) {
                Log.e(this.getClass().getName(), e.getClass().getName() + " (" + e.getMessage() + ") reading " + request.url().toString(), e);
                this.isError = true;
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
                Log.d(this.getClass().getName(), String.format("called %s in %dms and %dms to read %dB", request.url().toString(), connectTime, readTime, responseBody.length()));
            }

        } catch (IOException ioe) {
            Log.e(this.getClass().getName(), "Error (" + ioe.getMessage() + ") calling " + request.url().toString(), ioe);
            this.isError = true;
            return;
        }
    }

    /**
     * Construct and empty/offline response.  Signals that the call was not made.
     */
    public APIResponse(Context context) {
        this.isError = true;
    }

    public boolean isError() {
        return this.isError;
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

    /**
     * Special binder for LoginResponses, since they can't inherit from NewsBlurResponse due to
     * the design of the API fields.
     */ 
    public LoginResponse getLoginResponse(Gson gson) {
        if (this.isError) {
            LoginResponse response = new LoginResponse();
            response.isProtocolError = true;
            return response;
        } else {
            LoginResponse response = gson.fromJson(this.responseBody, LoginResponse.class);
            return response;
        }
    }

    /**
     * Special binder for RegisterResponses, since they can't inherit from NewsBlurResponse due to
     * the design of the API fields.
     */ 
    public RegisterResponse getRegisterResponse(Gson gson) {
        if (this.isError) {
            RegisterResponse response = new RegisterResponse();
            response.isProtocolError = true;
            return response;
        } else {
            RegisterResponse response = gson.fromJson(this.responseBody, RegisterResponse.class);
            return response;
        }
    }

    public String getResponseBody() {
        return this.responseBody;
    }

    public String getCookie() {
        return this.cookie;
    }

}
