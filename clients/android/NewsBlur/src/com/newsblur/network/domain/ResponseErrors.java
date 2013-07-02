package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;

public class ResponseErrors {

	@SerializedName("__all__")
	public String[] message;

	@SerializedName("email")
	public String[] email;

	@SerializedName("username")
	public String[] username;
}
