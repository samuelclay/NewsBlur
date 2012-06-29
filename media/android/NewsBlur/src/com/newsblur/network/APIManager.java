package com.newsblur.network;

import org.apache.http.HttpStatus;

import android.content.ContentValues;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.util.Log;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.newsblur.domain.FeedUpdate;
import com.newsblur.domain.FolderStructure;
import com.newsblur.network.domain.LoginResponse;
import com.newsblur.serialization.FolderStructureTypeAdapter;

public class APIManager {
	
	private static final String TAG = "APIManager";
	private Context context;
	private SharedPreferences preferences;
	private Gson gson;
	
	public APIManager(final Context context) {
		this.context = context;
		preferences = context.getSharedPreferences(APIConstants.PREFERENCES, 0);
		GsonBuilder builder = new GsonBuilder();
		builder.registerTypeAdapter(FolderStructure.class, new FolderStructureTypeAdapter());
		gson = builder.create();
	}
	
	public LoginResponse login(final String username, final String password) {
		APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.USERNAME, username);
		values.put(APIConstants.PASSWORD, password);
		final APIResponse response = client.post(APIConstants.URL_LOGIN, values);
		if (response.responseCode == HttpStatus.SC_OK && response.hasRedirected == false) {
			
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
		FeedUpdate feedUpdate = gson.fromJson(response.responseString, FeedUpdate.class);
		Log.d(TAG, "Retrieved feeds");
	}

}
