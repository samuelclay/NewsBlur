package com.newsblur.network.domain;

public class LoginResponse {
	
	// {"code": -1, "authenticated": false, "errors": {"__all__": ["That username is not registered. Create an account with it instead."]}, "result": "ok"}
	// {"code": -1, "authenticated": false, "errors": {"username": ["Please enter a username."]}, "result": "ok"}

	public boolean authenticated;
	public int code;
	public LoginErrors errors;
	public String result;
	
}
