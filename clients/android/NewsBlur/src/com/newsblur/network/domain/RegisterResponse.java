package com.newsblur.network.domain;

import com.google.gson.annotations.SerializedName;

/* note: this class cannot extend NewsBlurResponse like all other responses, since it makes the
         "errors" member an object rather than a list. this one call needs to duplicate most of
         the common response elements but allow for the one-off error handling. */
public class RegisterResponse {

    // not part of the response schema, but populated by the API manager to indicate
    // that we never got *any* valid JSON back
    public boolean isProtocolError = false;

	public boolean authenticated;
    public RegisterResponseErrors errors;

    public class RegisterResponseErrors {
        public String[] email;
        public String[] username;
        @SerializedName("__all__")
        public String[] other;
    }

    /**
     * Rather than just have a field like "error" or "message", the registration API returns
     * a complex "errors" object with one or more specially-named members that can contain
     * user-facing error messages if registration fails. This method attempts to extract a
     * user-vendable message from one of those fields, or null if none is found.
     */
    public String getErrorMessage() {
        String errorMessage = null;
        if(errors != null && errors.email != null && errors.email.length > 0) {
            errorMessage = errors.email[0];
        }
        if(errors != null && errors.username != null && errors.username.length > 0) {
            errorMessage = errors.username[0];
        }
        if(errors != null && errors.other != null && errors.other.length > 0) {
            errorMessage = errors.other[0];
        }
        return errorMessage;
    } 
    
}
