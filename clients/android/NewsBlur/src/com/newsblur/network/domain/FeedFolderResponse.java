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
import com.google.gson.stream.JsonReader;
import com.newsblur.domain.Feed;
import com.newsblur.domain.SocialFeed;
import com.newsblur.util.AppConstants;

public class FeedFolderResponse {
	
	@SerializedName("starred_count")
	public int starredCount;
	
	@SerializedName("feeds")
	public Map<String, Feed> feeds;
	
	@SerializedName("flat_folders")
	public Map<String, List<Long>> folders;
	
	@SerializedName("social_feeds")
	public SocialFeed[] socialFeeds;

	public boolean isAuthenticated;
	
	public FeedFolderResponse(String json, Gson gson) {

        // TODO: is there really any good reason the default GSON parser doesn't work here?
		JsonParser parser = new JsonParser();
		JsonObject asJsonObject = parser.parse(json).getAsJsonObject();

        this.isAuthenticated = asJsonObject.get("authenticated").getAsBoolean();

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
        
        // sometimes the API won't declare the top-level/root folder, but most of the
        // codebase expects it to exist.  Declare it as empty if missing.
        if (!folders.containsKey(AppConstants.ROOT_FOLDER)) {
            folders.put(AppConstants.ROOT_FOLDER, new ArrayList<Long>());
            Log.d( this.getClass().getName(), "root folder was missing.  added it.");
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
            // a null key means we are at the root.  give these a pseudo-folder name, since the DB and many
            // classes would be very unhappy with a null foldername.
            builder.append(AppConstants.ROOT_FOLDER);
        }
		return builder.toString();
	}
	
}
