package com.newsblur.network;

public abstract class BaseLoaderResponse {

	protected String errorMessage;
	protected boolean hasError;

	public BaseLoaderResponse() {
	}

	/**
	 * Use if the loader had a problem that needs to be communicated back to
	 * user
	 * 
	 * @param errorMessage
	 */
	public BaseLoaderResponse(String errorMessage) {
		this.errorMessage = errorMessage;
		this.hasError = true;
	}

	public String getErrorMessage() {
		return errorMessage;
	}

	public boolean hasError() {
		return hasError;
	}
}
