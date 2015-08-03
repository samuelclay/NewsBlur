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
	public ResponseErrors errors;
    public long readTime;

    public static final Pattern KnownUserErrors = Pattern.compile("cannot mark as unread");

    public boolean isError() {
        if ((message != null) && (!message.equals(""))) {
            Log.d(this.getClass().getName(), "Response interpreted as error due to 'message' field: " + message);
            return true;
        }
        if ((errors != null) && (errors.message != null) && (errors.message.length > 0) && (errors.message[0] != null)) {
            Log.d(this.getClass().getName(), "Response interpreted as error due to 'ResponseErrors' field: " + errors.message[0]);
            return true;
        }
        return false;
    }

    // TODO: can we add a canonical flag of some sort to 100% of API responses that differentiates
    //       between 400-type and 2/3/500-type errors? Until then, we have to sniff known bad ones.
    public boolean isUserError() {
        if (message != null) {
            Matcher m = KnownUserErrors.matcher(message);
            if (m.find()) return true;
        }
        if ((errors != null) && (errors.message.length > 0) && (errors.message[0] != null)) {
            Matcher m = KnownUserErrors.matcher(errors.message[0]);
            if (m.find()) return true;
        }
        return false;
    }

    /**
     * Gets the error message returned by the API, or defaultMessage if none was found.
     */
    public String getErrorMessage(String defaultMessage) {
        if ((message != null) && (!message.equals(""))) return message;
        if ((errors != null) &&(errors.message != null) && (errors.message.length > 0) && (errors.message[0] != null)) return errors.message[0];
        return defaultMessage;
    }

    /**
     * Gets the error message returned by the API, or a simple numeric error code if non was found.
     */
    public String getErrorMessage() {
        return getErrorMessage(Integer.toString(code));
    }
}
