package com.newsblur.network;

import java.util.ArrayList;

import android.content.Context;
import android.support.v4.content.AsyncTaskLoader;

import com.newsblur.domain.FeedResult;

public class SearchAsyncTaskLoader extends AsyncTaskLoader<ArrayList<FeedResult>> {

	public static final String SEARCH_TERM = "searchTerm";
	
	private String searchTerm;
	private APIManager apiManager;

	public SearchAsyncTaskLoader(Context context, String searchTerm) {
		super(context);
		this.searchTerm = searchTerm;
		apiManager = new APIManager(context);
	}

	@Override
	public ArrayList<FeedResult> loadInBackground() {
		ArrayList<FeedResult> list = new ArrayList<FeedResult>();
		for (FeedResult result : apiManager.searchForFeed(searchTerm)) {
			list.add(result);
		}
		
		return list;
	}

}
