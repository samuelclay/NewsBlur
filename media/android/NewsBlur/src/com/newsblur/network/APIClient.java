package com.newsblur.network;

import java.io.File;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.UnsupportedEncodingException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.List;
import java.util.Map.Entry;
import java.util.Scanner;

import com.newsblur.activity.PrefConstants;

import android.content.ContentValues;
import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;
import android.util.Log;

public class APIClient {

	private static final String TAG = "APIClient";
	private Context context;

	public APIClient(final Context context) {
		this.context = context;
		// enableHttpResponseCache();
	}

	public APIResponse get(final String urlString) {
		HttpURLConnection connection = null;
		try {
			final URL urlFeeds = new URL(urlString);
			connection = (HttpURLConnection) urlFeeds.openConnection();
			final SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
			final String cookie = preferences.getString(PrefConstants.PREF_COOKIE, null);
			if (cookie != null) {
				connection.setRequestProperty("Cookie", cookie);
			}
			return extractResponse(urlFeeds, connection);
		} catch (IOException e) {
			Log.d(TAG, "Error opening GET connection to " + urlString, e.getCause());
			return new APIResponse();
		} finally {
			connection.disconnect();
		}
	}
	
	public APIResponse get(final String urlString, final ContentValues values) {
		HttpURLConnection connection = null;
		try {
			List<String> parameters = new ArrayList<String>();
			for (Entry<String, Object> entry : values.valueSet()) {
				final StringBuilder builder = new StringBuilder();
				builder.append((String) entry.getKey());
				builder.append("=");
				builder.append((String) entry.getValue());
				parameters.add(builder.toString());
			}
			final String parameterString = TextUtils.join("&", parameters);

			final URL urlFeeds = new URL(urlString + "?" + parameterString);
			connection = (HttpURLConnection) urlFeeds.openConnection();
			
			final SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
			final String cookie = preferences.getString(PrefConstants.PREF_COOKIE, null);
			if (cookie != null) {
				connection.setRequestProperty("Cookie", cookie);
			}
			return extractResponse(urlFeeds, connection);
		} catch (IOException e) {
			Log.d(TAG, "Error opening GET connection to " + urlString, e.getCause());
			return new APIResponse();
		} finally {
			connection.disconnect();
		}
	}

	private APIResponse extractResponse(final URL url, HttpURLConnection connection) throws IOException {
		StringBuilder builder = new StringBuilder();
		final Scanner scanner = new Scanner(connection.getInputStream());
		while (scanner.hasNextLine()) {
			builder.append(scanner.nextLine());
		}
		
		final APIResponse response = new APIResponse();
		response.responseString = builder.toString();
		response.responseCode = connection.getResponseCode();
		response.cookie = connection.getHeaderField("Set-Cookie");
		response.hasRedirected = !TextUtils.equals(url.getHost(), connection.getURL().getHost());

		return response;
	}

	public APIResponse post(final String urlString, final ContentValues values) {
		HttpURLConnection connection = null;

		List<String> parameters = new ArrayList<String>();
		for (Entry<String, Object> entry : values.valueSet()) {
			final StringBuilder builder = new StringBuilder();
			builder.append((String) entry.getKey());
			builder.append("=");
			try {
				builder.append(URLEncoder.encode((String) entry.getValue(), "UTF-8"));
			} catch (UnsupportedEncodingException e) {
				Log.d(TAG, "Unable to URLEncode a parameter in a POST");
				builder.append((String) entry.getValue());
			}
			parameters.add(builder.toString());
		}
		final String parameterString = TextUtils.join("&", parameters);

		try {
			final URL url = new URL(urlString);
			connection = (HttpURLConnection) url.openConnection();
			connection.setDoOutput(true);
			connection.setRequestMethod("POST");
			connection.setFixedLengthStreamingMode(parameterString.getBytes().length);
			connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
			final PrintWriter printWriter = new PrintWriter(connection.getOutputStream());
			printWriter.print(parameterString);
			printWriter.close();

			return extractResponse(url, connection);
		} catch (IOException e) {
			Log.d(TAG, "Error opening POST connection to " + urlString + ": " + e.getLocalizedMessage(), e.getCause());
			return new APIResponse();
		} finally {
			if (connection != null) {
				connection.disconnect();
			}
		}
	}

	/*
	 * This method enables HTTP Response cache should the device support it.
	 * See Android Developer's Blog for more detail: http://android-developers.blogspot.ca/2011/09/androids-http-clients.html
	 */
	private void enableHttpResponseCache() {
		Log.d(TAG, "Enabling HttpResponseCache");
		try {
			final long httpCacheSize = 10 * 1024 * 1024; //
			File httpCacheDir = new File(context.getCacheDir(), "http");
			if (httpCacheDir != null) {
				Class.forName("android.net.http.HttpResponseCache").getMethod("install", File.class, long.class).invoke(null, httpCacheDir, httpCacheSize);
			}
		} catch (Exception httpResponseCacheNotAvailable) {
			Log.d(TAG, "No HttpResponseCache available", httpResponseCacheNotAvailable.getCause());
		}
	}

}
