package com.newsblur.network;

import org.apache.http.HttpStatus;

import android.content.ContentValues;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;

import com.google.gson.Gson;
import com.newsblur.network.domain.LoginResponse;

public class APIManager {
	
	private Context context;
	private SharedPreferences preferences;
	
	public APIManager(final Context context) {
		this.context = context;
		preferences = context.getSharedPreferences(APIConstants.PREFERENCES, 0);
	}
	
	public LoginResponse login(final String username, final String password) {
		APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.USERNAME, username);
		values.put(APIConstants.PASSWORD, password);
		final APIResponse response = client.post(APIConstants.URL_LOGIN, values);
		if (response.responseCode == HttpStatus.SC_OK && response.hasRedirected == false) {
			Gson gson = new Gson();
			LoginResponse loginResponse = gson.fromJson(response.responseString, LoginResponse.class);
			final Editor edit = preferences.edit();
			edit.putString(APIConstants.PREF_COOKIE, response.cookie);
			edit.commit();
			return loginResponse;
		} else {
			return new LoginResponse();
		}		
	}
	
	public void getFeeds() {
		APIClient client = new APIClient(context);
		final APIResponse response = client.get(APIConstants.URL_FEEDS);
		
	}

}
