package com.newsblur.network.domain;

import android.util.Log;

/**
 * A response handler for /api/login calls, since their error format is different than
 * the rest of the API. GSON won't allow multiple declarations of fields, and since all
 * other NewsBlur API responses other than this one encode the "errors" field as an array
 * of strings, we can't just override NewsBlurResponse.
 */
public class LoginResponse {

    // not part of the response schema, but populated by the API manager to indicate
    // that we never got *any* valid JSON back
    public boolean isProtocolError = false;

    // Normally, the 'errors' field in the JSON response is an array of string values. For the
    // login API, however, it returns an *object* containing an array of string values.
	public ResponseErrors errors;

    public boolean isError() {
        if (isProtocolError) return true;
        if ((errors != null) && (errors.message != null) && (errors.message.length > 0) && (errors.message[0] != null)) {
            Log.d(this.getClass().getName(), "Response interpreted as error due to 'ResponseErrors' field: " + errors.message[0]);
            return true;
        }
        return false;
    }

    /**
     * Gets the error message returned by the API, or defaultMessage if none was found.
     */
    public String getErrorMessage(String defaultMessage) {
        if ((errors != null) &&(errors.message != null) && (errors.message.length > 0) && (errors.message[0] != null)) return errors.message[0];
        return defaultMessage;
    }

}
