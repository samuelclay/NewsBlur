package com.newsblur.network;

import org.apache.http.HttpStatus;

import com.google.gson.Gson;
import com.newsblur.network.domain.LoginResponse;

import android.content.ContentValues;
import android.content.Context;

public class APIManager {
	
	private Context context;
	
	public APIManager(final Context context) {
		this.context = context;
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
			return loginResponse;
		} else {
			return new LoginResponse();
		}		
	}

}
