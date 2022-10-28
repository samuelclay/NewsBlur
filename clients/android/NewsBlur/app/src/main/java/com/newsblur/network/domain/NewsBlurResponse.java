package com.newsblur.network.domain;

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
    public int impactCode;

    public boolean isError() {
        if (isProtocolError) return true;
        if ((message != null) && (!message.equals("")) && (!message.equals("OK"))) {
            // NB: some valid POSTs use the message field for an error and some for a UX message, and we have no way of knowing the difference
            com.newsblur.util.Log.d(this.getClass().getName(), "Response interpreted as fatal due to 'message' field: " + message);
            return true;
        }
        if ((errors != null) && (errors.length > 0) && (errors[0] != null)) {
            com.newsblur.util.Log.d(this.getClass().getName(), "Response interpreted as error due to 'errors' field: " + errors[0]);
            return true;
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
