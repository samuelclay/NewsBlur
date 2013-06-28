package com.newsblur.network.domain;

/**
 * A generic response to an API call that only encapsuates success versus failure.
 */
public class NewsBlurResponse {

	public boolean authenticated;
	public int code;
    public String message;
	public String[] errors;

    public boolean isError() {
        if (message != null) return true;
        if ((errors != null) && (errors.length > 0) && (errors[0] != null)) return true;
        return false;
    }

    public String getErrorMessage() {
        if (message != null) return message;
        if ((errors != null) && (errors.length > 0) && (errors[0] != null)) return errors[0];
        return Integer.toString(code);
    }

}
