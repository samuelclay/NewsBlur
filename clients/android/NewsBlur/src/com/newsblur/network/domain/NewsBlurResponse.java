package com.newsblur.network.domain;

import android.util.Log;

/**
 * A generic response to an API call that only encapsuates success versus failure.
 */
public class NewsBlurResponse {

	public boolean authenticated;
	public int code;
    public String message;
	public ResponseErrors errors;
    public String result;

    public boolean isError() {
        if ((message != null) && (!message.equals(""))) {
            Log.d(this.getClass().getName(), "Response interpreted as error due to 'message' field: " + message);
            return true;
        }
        if ((errors != null) && (errors.message.length > 0) && (errors.message[0] != null)) {
            Log.d(this.getClass().getName(), "Response interpreted as error due to 'ResponseErrors' field: " + errors.message[0]);
            return true;
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
