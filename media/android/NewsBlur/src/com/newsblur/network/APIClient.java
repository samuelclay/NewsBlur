package com.newsblur.network;

import java.io.IOException;
import java.io.PrintWriter;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.List;
import java.util.Map.Entry;
import java.util.Scanner;

import android.content.ContentValues;
import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;
import android.util.Log;

import com.newsblur.domain.ValueMultimap;
import com.newsblur.util.NetworkUtils;
import com.newsblur.util.PrefConstants;

public class APIClient {

	private static final String TAG = "APIClient";
	private Context context;

	public APIClient(final Context context) {
		this.context = context;
	}

	public APIResponse get(final String urlString) {
		HttpURLConnection connection = null;
		if (!NetworkUtils.isOnline(context)) {
			APIResponse response = new APIResponse();
			response.isOffline = true;
			return response;
		}
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
			Log.e(TAG, "Error opening GET connection to " + urlString, e.getCause());
			return new APIResponse();
		} finally {
			connection.disconnect();
		}
	}
	
	public APIResponse get(final String urlString, final ContentValues values) {
		HttpURLConnection connection = null;
		if (!NetworkUtils.isOnline(context)) {
			APIResponse response = new APIResponse();
			response.isOffline = true;
			return response;
		}
		try {
			List<String> parameters = new ArrayList<String>();
			for (Entry<String, Object> entry : values.valueSet()) {
				final StringBuilder builder = new StringBuilder();
				builder.append((String) entry.getKey());
				builder.append("=");
				builder.append(URLEncoder.encode((String) entry.getValue()));
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
			Log.e(TAG, "Error opening GET connection to " + urlString, e.getCause());
			return new APIResponse();
		} finally {
			if (connection != null) {
				connection.disconnect();
			}
		}
	}
	
	public APIResponse get(final String urlString, final ValueMultimap valueMap) {
		HttpURLConnection connection = null;
		if (!NetworkUtils.isOnline(context)) {
			APIResponse response = new APIResponse();
			response.isOffline = true;
			return response;
		}
		try {
			String parameterString = valueMap.getParameterString();

			final URL urlFeeds = new URL(urlString + "?" + parameterString);
			connection = (HttpURLConnection) urlFeeds.openConnection();

			final SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
			final String cookie = preferences.getString(PrefConstants.PREF_COOKIE, null);
			if (cookie != null) {
				connection.setRequestProperty("Cookie", cookie);
			}
			return extractResponse(urlFeeds, connection);
		} catch (IOException e) {
			Log.e(TAG, "Error opening GET connection to " + urlString, e.getCause());
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
		if (!NetworkUtils.isOnline(context)) {
			APIResponse response = new APIResponse();
			response.isOffline = true;
			return response;
		}
		List<String> parameters = new ArrayList<String>();
		for (Entry<String, Object> entry : values.valueSet()) {
			final StringBuilder builder = new StringBuilder();
			
			builder.append((String) entry.getKey());
			builder.append("=");
			builder.append((String) entry.getValue());
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
			
			final SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
			final String cookie = preferences.getString(PrefConstants.PREF_COOKIE, null);
			if (cookie != null) {
				connection.setRequestProperty("Cookie", cookie);
			}
			
			final PrintWriter printWriter = new PrintWriter(connection.getOutputStream());
			printWriter.print(parameterString);
			printWriter.close();

			return extractResponse(url, connection);
		} catch (IOException e) {
			Log.e(TAG, "Error opening POST connection to " + urlString + ": " + e.getCause(), e.getCause());
			return new APIResponse();
		} finally {
			if (connection != null) {
				connection.disconnect();
			}
		}
	}
	
	public APIResponse post(final String urlString, final ValueMultimap valueMap) {
		return post(urlString, valueMap, true);
	}
	
	public APIResponse post(final String urlString, final ValueMultimap valueMap, boolean jsonIfy) {
		HttpURLConnection connection = null;
		if (!NetworkUtils.isOnline(context)) {
			APIResponse response = new APIResponse();
			response.isOffline = true;
			return response;
		}
		
		try {
			final URL url = new URL(urlString);
			connection = (HttpURLConnection) url.openConnection();
			connection.setDoOutput(true);
			connection.setRequestMethod("POST");
			String parameterString = jsonIfy ? valueMap.getJsonString() : valueMap.getParameterString();
			connection.setFixedLengthStreamingMode(parameterString.getBytes().length);
			connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded");
			
			final SharedPreferences preferences = context.getSharedPreferences(PrefConstants.PREFERENCES, 0);
			final String cookie = preferences.getString(PrefConstants.PREF_COOKIE, null);
			if (cookie != null) {
				connection.setRequestProperty("Cookie", cookie);
			}
			
			final PrintWriter printWriter = new PrintWriter(connection.getOutputStream());
			printWriter.print(parameterString);
			printWriter.close();

			return extractResponse(url, connection);
		} catch (IOException e) {
			Log.e(TAG, "Error opening POST connection to " + urlString + ": " + e.getCause(), e.getCause());
			return new APIResponse();
		} finally {
			if (connection != null) {
				connection.disconnect();
			}
		}
	}
}
