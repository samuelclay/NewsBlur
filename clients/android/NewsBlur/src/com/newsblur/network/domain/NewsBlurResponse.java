package com.newsblur.network.domain;

import android.util.Log;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * A generic response to an API call that only encapsuates success versus failure.
 */
public class NewsBlurResponse {

    // not part of the response schema, but populated by the API manager to indicate
    // that we never got *any* valid JSON back
    public boolean isProtocolError = false;

	public boolean authenticated;
	public int code;
    public String message;
	public String[] errors;
    public long readTime;

    public static final Pattern KnownUserErrors = Pattern.compile("cannot mark as unread");

    public boolean isError() {
        if (isProtocolError) return true;
        if ((message != null) && (!message.equals(""))) {
            Log.d(this.getClass().getName(), "Response interpreted as error due to 'message' field: " + message);
            return true;
        }
        if ((errors != null) && (errors.length > 0) && (errors[0] != null)) {
            Log.d(this.getClass().getName(), "Response interpreted as error due to 'errors' field: " + errors[0]);
            return true;
        }
        return false;
    }

    // TODO: can we add a canonical flag of some sort to 100% of API responses that differentiates
    //       between user and server errors? Until then, we have to sniff known bad ones, since all
    //       user errors have a 200 response rather than a 4xx.
    public boolean isUserError() {
        String err = getErrorMessage(null);
        if (err != null) {
            Matcher m = KnownUserErrors.matcher(err);
            if (m.find()) return true;
        }
        return false;
    }

    /**
     * Gets the error message returned by the API, or defaultMessage if none was found.
     */
    public String getErrorMessage(String defaultMessage) {
        if ((message != null) && (!message.equals(""))) return message;
        if ((errors != null) && (errors.length > 0) && (errors[0] != null)) return errors[0];
        return defaultMessage;
    }

}
