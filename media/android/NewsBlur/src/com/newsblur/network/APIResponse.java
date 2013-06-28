package com.newsblur.network;

import java.io.InputStreamReader;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;

import android.content.Context;
import android.text.TextUtils;
import android.util.Log;

import com.google.gson.Gson;
import com.google.gson.stream.JsonReader;
import org.apache.http.HttpStatus;

import com.newsblur.R;
import com.newsblur.network.domain.NewsBlurResponse;

/**
 * A JSON-encoded response from the API servers.  This class encodes the possible outcomes of
 * an attempted API call, including total failure, online failures, and successful responses.
 * In the latter case, the GSON reader used to look for errors is left open so that the expected
 * response can be read.  Instances of this class should be closed after use.
 */
public class APIResponse {
	
    private Context context;
    private HttpURLConnection connection;
    private boolean isError;
    private String errorMessage;
	private String cookie;
    private JsonReader gsonReader;

    /**
     * Construct an online response.  Will test the response for errors and extract all the
     * info we might need.
     */
    public APIResponse(Context context, URL originalUrl, HttpURLConnection connection) {

        this.context = context;
        this.connection = connection;

        this.errorMessage = context.getResources().getString(R.string.error_unset_message);

        try {
            if (connection.getResponseCode() != HttpStatus.SC_OK) {
                Log.e(this.getClass().getName(), "API returned error code " + connection.getResponseCode() + " calling " + originalUrl);
                this.isError = true;
                this.errorMessage = context.getResources().getString(R.string.error_http_connection);
                return;
            }
            
            if (!TextUtils.equals(originalUrl.getHost(), connection.getURL().getHost())) {
                // TODO: the existing code rejects redirects as errors.  Is this correct?
                Log.e(this.getClass().getName(), "API redirected calling " + originalUrl);
                this.isError = true;
                this.errorMessage = context.getResources().getString(R.string.error_http_connection);
                return;
            }
        } catch (IOException ioe) {
            Log.e(this.getClass().getName(), "Error (" + ioe.getMessage() + ") calling " + originalUrl, ioe);
            this.isError = true;
            this.errorMessage = context.getResources().getString(R.string.error_read_connection);
            return;
        }

        this.cookie = connection.getHeaderField("Set-Cookie");

        // make a GSON streaming reader for the response
        try {
            this.gsonReader = new JsonReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));
        } catch (Exception e) {
            Log.e(this.getClass().getName(), e.getClass().getName() + " (" + e.getMessage() + ") calling " + originalUrl, e);
            this.isError = true;
            this.errorMessage = context.getResources().getString(R.string.error_read_connection);
            return;
        }
        
    }

    /**
     * Construct and empty/offline response.  Signals that the call was not made.
     */
    public APIResponse(Context context) {
        this.context = context;
        this.isError = true;
        this.errorMessage = context.getResources().getString(R.string.error_offline);
    }

    public boolean isError() {
        return this.isError;
    }

    /**
     * Get the GSON reader that will have been left open for use if the API call was successful.
     */
    public JsonReader getGsonReader() {
        return this.gsonReader;
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
            NewsBlurResponse response = new NewsBlurResponse();
            response.message = this.errorMessage;
            this.close();
            return ((T) response);
        } else {
            // otherwise, parse the response as the expected class and defer error detection
            // to the NewsBlurResponse parent class
            T response = gson.fromJson(this.gsonReader, classOfT);
            this.close();
            return response;
        }
    }

    public String getCookie() {
        return this.cookie;
    }

    public void close() {
        try {
            if (this.connection != null) this.connection.disconnect();
            if (this.gsonReader != null) this.gsonReader.close();
        } catch (Exception e) {
            Log.e(this.getClass().getName(), "Error closing API connection.", e);
        }
    }

}
