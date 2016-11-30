package com.newsblur.network.domain;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map.Entry;
import java.util.Set;

import android.util.Log;
import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.domain.SocialFeed;
import com.newsblur.domain.StarredCount;
import com.newsblur.util.AppConstants;

public class FeedFolderResponse {
    
    /** Helper variables so users of the parser can pass along instrumentation. */
    public long connTime;
    public long readTime;
    public long parseTime;
	
    public Set<Folder> folders;
	public Set<Feed> feeds;
	public Set<SocialFeed> socialFeeds;
    public Set<StarredCount> starredCounts;
	
	public boolean isAuthenticated;
    public boolean isPremium;
    public boolean isStaff;
	public int starredCount;
	
	public FeedFolderResponse(String json, Gson gson) {
        long startTime = System.currentTimeMillis();

		JsonParser parser = new JsonParser();
		JsonObject asJsonObject = parser.parse(json).getAsJsonObject();

        this.isAuthenticated = asJsonObject.get("authenticated").getAsBoolean();
        if (asJsonObject.has("is_staff")) {
            this.isStaff = asJsonObject.get("is_staff").getAsBoolean();
        }

        JsonElement userProfile = asJsonObject.get("user_profile");
        if (userProfile != null) {
            JsonObject profile = (JsonObject) userProfile;
            this.isPremium = profile.get("is_premium").getAsBoolean();
        }

		JsonElement starredCountElement = asJsonObject.get("starred_count");
		if(starredCountElement != null) {
			starredCount = gson.fromJson(starredCountElement, int.class);
		}

        folders = new HashSet<Folder>();
        JsonArray jsonFoldersArray = (JsonArray) asJsonObject.get("folders");
        // recursively parse folders
		parseFolderArray(new ArrayList<String>(0), null, jsonFoldersArray);
		
		// Inconsistent server response here. When user has no feeds we get an empty array, otherwise an object
		JsonElement feedsElement = asJsonObject.get("feeds");
		feeds = new HashSet<Feed>();
		if(feedsElement instanceof JsonObject) {
			JsonObject feedsObject = (JsonObject) asJsonObject.get("feeds");
			if(feedsObject != null) {
				Set<Entry<String, JsonElement>> entrySet = feedsObject.entrySet();
				Iterator<Entry<String, JsonElement>> iterator = entrySet.iterator();
				while(iterator.hasNext()) {
					Entry<String, JsonElement> feedElement = iterator.next();
					Feed feed = gson.fromJson(feedElement.getValue(), Feed.class);
					feeds.add(feed);
				}
			}
		} // else server sent back '"feeds": []' 
		
		socialFeeds = new HashSet<SocialFeed>();
		JsonArray socialFeedsArray = (JsonArray) asJsonObject.get("social_feeds");
		if(socialFeedsArray != null) {
			for(int i=0;i<socialFeedsArray.size();i++) {
				JsonElement jsonElement = socialFeedsArray.get(i);
				SocialFeed socialFeed = gson.fromJson(jsonElement, SocialFeed.class);
				socialFeeds.add(socialFeed);
			}
		}
        
        // sometimes the API won't declare the top-level/root folder, but most of the
        // codebase expects it to exist.  Declare it as empty if missing.
        Folder emptyRootFolder = new Folder();
        emptyRootFolder.name = AppConstants.ROOT_FOLDER;
        // equality is based on folder name, so contains() will work
        if (!folders.contains(emptyRootFolder)) {
            folders.add(emptyRootFolder);
            Log.d( this.getClass().getName(), "root folder was missing.  added it.");
        } 

        starredCounts = new HashSet<StarredCount>();
        JsonArray starredCountsArray = (JsonArray) asJsonObject.get("starred_counts");
        if (starredCountsArray != null) {
            for (int i=0; i<starredCountsArray.size(); i++) {
                JsonElement jsonElement = starredCountsArray.get(i);
                StarredCount sc = gson.fromJson(jsonElement, StarredCount.class);
                starredCounts.add(sc);
            }
        }

        parseTime = System.currentTimeMillis() - startTime;
	}
	
	/**
     * Parses a folder, which is a list of feeds and/or more folders.
     *
     * @param parentName folder that surrounded this folder.
     * @param name the name of this folder or null if root.
     * @param arrayValue the contents to be parsed.
     */
    private void parseFolderArray(List<String> parentNames, String name, JsonArray arrayValue) {
        if (name == null) name = AppConstants.ROOT_FOLDER;
        List<String> children = new ArrayList<String>();
		List<String> feedIds = new ArrayList<String>();
		for (JsonElement jsonElement : arrayValue) {
            // a folder array contains either feed IDs or nested folder objects
			if(jsonElement.isJsonPrimitive()) {
				feedIds.add(jsonElement.getAsString());
			} else if (jsonElement.isJsonObject()) {
                // if it wasn't a feed ID, it is a nested folder object
                Set<Entry<String, JsonElement>> entrySet = ((JsonObject) jsonElement).entrySet();
                // recurse - nested folders are just objects with (usually one) field named for the folder
                // that is a list of contained feeds or additional folders
                for (Entry<String, JsonElement> next : entrySet) {
                    String nextName = next.getKey();
                    children.add(nextName);
                    List<String> appendedParentList = new ArrayList<String>(parentNames);
                    appendedParentList.add(name);
                    parseFolderArray(appendedParentList, nextName, (JsonArray) next.getValue());
                }
			} else {
                Log.w( this.getClass().getName(), "folder had null or malformed child: " + name);
            }
		}
        Folder folder = new Folder();
        folder.name = name;
        folder.parents = parentNames;
        folder.children = children;
        folder.feedIds = feedIds;
        folders.add(folder);
	}

}
