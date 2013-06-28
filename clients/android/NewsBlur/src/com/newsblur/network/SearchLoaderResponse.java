package com.newsblur.network;

import java.util.ArrayList;

import com.newsblur.domain.FeedResult;

public class SearchLoaderResponse extends BaseLoaderResponse {

	private ArrayList<FeedResult> results;

	/**
	 * Use to indicate there was a problem w/ the search
	 * 
	 * @param errorMessage
	 */
	public SearchLoaderResponse(String errorMessage) {
		super(errorMessage);
		results = new ArrayList<FeedResult>(0);
	}
	
	public SearchLoaderResponse(ArrayList<FeedResult> results) {
		this.results = results;
	}
	
	public ArrayList<FeedResult> getResults() {
		return results;
	}


}
