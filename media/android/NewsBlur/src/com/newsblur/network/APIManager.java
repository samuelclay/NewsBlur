package com.newsblur.network;

import org.apache.http.HttpStatus;

import android.content.ContentValues;
import android.content.Context;

public class APIManager {
	
	private Context context;
	
	public APIManager(final Context context) {
		this.context = context;
	}
	
	public boolean login(final String username, final String password) {
		APIClient client = new APIClient(context);
		final ContentValues values = new ContentValues();
		values.put(APIConstants.USERNAME, username);
		values.put(APIConstants.PASSWORD, password);
		final APIResponse response = client.post(APIConstants.URL_LOGIN, values);
		
		// Consider the login complete if we've got a HTTP 200 and we've not been redirected
		// This could be made more granular depending on validity requirements.
		return (response.responseCode == HttpStatus.SC_OK && response.hasRedirected == false);
	}

}
