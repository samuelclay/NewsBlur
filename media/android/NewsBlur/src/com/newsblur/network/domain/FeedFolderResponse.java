package com.newsblur.network.domain;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Map.Entry;

import android.util.Log;
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
	
	/**
     * Parses a folder, which is a list of feeds and/or more folders.  Nested folders
     * are flattened into a single list, with names that are heirarchical.
     *
     * @param nestedFolderList a list of any parent folders that surrounded this folder.
     * @param folders the sink
     * @param name the name of this folder.
     * @param arrayValue the actual contents to be parsed.
     */
    private void parseFeedArray(List<String> nestedFolderList,
			Map<String, List<Long>> folders, String name, JsonArray arrayValue) {

        // determine our text name, like "grandparent - parent - me"    
		String fullFolderName = getFolderName(name, nestedFolderList);
        // sink for any feeds found in this folder
		ArrayList<Long> feedIds = new ArrayList<Long>();

		for (JsonElement jsonElement : arrayValue) {
            // a folder array contains either feed IDs or nested folder objects
			if(jsonElement.isJsonPrimitive()) {
				feedIds.add(jsonElement.getAsLong());
			} else {
                // if it wasn't a feed ID, it is a nested folder object
                Set<Entry<String, JsonElement>> entrySet = ((JsonObject) jsonElement).entrySet();
				List<String> nestedFolderListCopy = new ArrayList<String>(nestedFolderList);
				if(name != null) {
					nestedFolderListCopy.add(name);
				}
                // recurse - nested folders are just objects with (usually one) field named for the folder
                // that is a list of contained feeds or additional folders
                for (Entry<String, JsonElement> next : entrySet) {
                    parseFeedArray( nestedFolderListCopy, folders, next.getKey(), (JsonArray) next.getValue() );
                }
			}
		}
		folders.put(fullFolderName, feedIds);
        //Log.d( this.getClass().getName(), "parsed folder '" + fullFolderName + "' with " + feedIds.size() + " feeds" );
	}

	private String getFolderName(String key, List<String> parentFeedNames) {
		StringBuilder builder = new StringBuilder();
		for(String parentFolder: parentFeedNames) {
			builder.append(parentFolder);
			builder.append(" - ");
		}
		if(key != null) {
			builder.append(key);
		} else {
            //builder.append(" (no folder)");
        }
		return builder.toString();
	}
	
}
