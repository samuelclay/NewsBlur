package com.newsblur.network.domain;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Map.Entry;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.annotations.SerializedName;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SocialFeed;

public class FeedFolderResponse {
	
	@SerializedName("starred_count")
	public int starredCount;
	
	@SerializedName("feeds")
	public Map<String, Feed> feeds;
	
	@SerializedName("flat_folders")
	public Map<String, List<Long>> folders;
	
	@SerializedName("social_feeds")
	public SocialFeed[] socialFeeds;

	public FeedFolderResponse() {
	}
	
	public FeedFolderResponse(String json, Gson gson) {
		// This is a mess but I don't see a way to parse the mixed content in
		// folders w/o going to low level Gson API
		JsonParser parser = new JsonParser();
		JsonObject asJsonObject = parser.parse(json).getAsJsonObject();
		JsonArray jsonFoldersArray = (JsonArray) asJsonObject.get("folders");
		ArrayList<String> nestedFolderList = new ArrayList<String>();
		folders = new HashMap<String, List<Long>>();
		parseFeedArray(nestedFolderList, folders, null, jsonFoldersArray);
		
		JsonElement starredCountElement = asJsonObject.get("starred_count");
		if(starredCountElement != null) {
			starredCount = gson.fromJson(starredCountElement, int.class);
		}
		
		// Inconsistent server response here. When user has no feeds we get
		// 		"feeds": []
		// and other times we get
		// 		"feeds": {"309667": {
		// So support both I guess
		JsonElement feedsElement = asJsonObject.get("feeds");
		feeds = new HashMap<String, Feed>();
		if(feedsElement instanceof JsonObject) {
			JsonObject feedsObject = (JsonObject) asJsonObject.get("feeds");
			if(feedsObject != null) {
				Set<Entry<String, JsonElement>> entrySet = feedsObject.entrySet();
				Iterator<Entry<String, JsonElement>> iterator = entrySet.iterator();
				while(iterator.hasNext()) {
					Entry<String, JsonElement> feedElement = iterator.next();
					Feed feed = gson.fromJson(feedElement.getValue(), Feed.class);
					feeds.put(feedElement.getKey(), feed);
				}
			}
		} // else server sent back '"feeds": []' 
		
		socialFeeds = new SocialFeed[0];
		JsonArray socialFeedsArray = (JsonArray) asJsonObject.get("social_feeds");
		if(socialFeedsArray != null) {
			List<SocialFeed> socialFeedsList = new ArrayList<SocialFeed>();
			for(int i=0;i<socialFeedsArray.size();i++) {
				JsonElement jsonElement = socialFeedsArray.get(i);
				SocialFeed socialFeed = gson.fromJson(jsonElement, SocialFeed.class);
				socialFeedsList.add(socialFeed);
			}
			socialFeeds = socialFeedsList.toArray(new SocialFeed[socialFeedsArray.size()]);
		}
	}
	
	private void parseFeed(JsonObject asJsonObject2, List<String> parentFeedNames, Map<String, List<Long>> folders) {
		Set<Entry<String, JsonElement>> entrySet = asJsonObject2.entrySet();
		Iterator<Entry<String, JsonElement>> iterator = entrySet.iterator();
		while(iterator.hasNext()) {
			Entry<String, JsonElement> next = iterator.next();
			String key = next.getKey();
			JsonArray value = (JsonArray) next.getValue();
			parseFeedArray(parentFeedNames, folders, key, value);
		}
	}

	private void parseFeedArray(List<String> nestedFolderList,
			Map<String, List<Long>> folders, String name, JsonArray arrayValue) {
		String fullFolderName = getFolderName(name, nestedFolderList);
		ArrayList<Long> feedIds = new ArrayList<Long>();
		for(int k=0;k<arrayValue.size();k++) {
			JsonElement jsonElement = arrayValue.get(k);
			if(jsonElement.isJsonPrimitive()) {
				feedIds.add(jsonElement.getAsLong());
			} else {
				List<String> nestedFolerListCopy = new ArrayList<String>(nestedFolderList);
				if(name != null) {
					nestedFolerListCopy.add(name);
				}
				parseFeed((JsonObject) jsonElement, nestedFolerListCopy, folders);
			}
		}
		folders.put(fullFolderName, feedIds);
	}

	private String getFolderName(String key, List<String> parentFeedNames) {
		StringBuilder builder = new StringBuilder();
		for(String parentFolder: parentFeedNames) {
			builder.append(parentFolder);
			builder.append(" - ");
		}
		if(key != null) {
			builder.append(key);
		}
		return builder.toString();
	}
	
}
