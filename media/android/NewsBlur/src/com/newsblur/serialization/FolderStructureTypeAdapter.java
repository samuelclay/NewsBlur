package com.newsblur.serialization;

import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;

import com.google.gson.JsonArray;
import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.newsblur.domain.FolderStructure;

public class FolderStructureTypeAdapter implements JsonDeserializer<FolderStructure> {

	private String TAG = "FolderStructureTypeAdapter";
	private Map<String, List<Long>> folderFeeds;

	@Override
	public FolderStructure deserialize(JsonElement jsonElement, Type type, JsonDeserializationContext context) throws JsonParseException {
		Iterator<JsonElement> jsonFolderArray = jsonElement.getAsJsonArray().iterator();
		folderFeeds = new HashMap<String, List<Long>>();
		
		while (jsonFolderArray.hasNext()) {
			JsonElement nextElement = jsonFolderArray.next();
			if (nextElement.isJsonPrimitive()) {
				addFeedToFolder(null, nextElement.getAsLong());
			} else if (nextElement.isJsonObject()) {
				JsonObject asJsonObject = nextElement.getAsJsonObject();
				for (Entry<String, JsonElement> entry : asJsonObject.entrySet()) {
					final String folderName = (String) entry.getKey();
					final JsonArray feedIds = (JsonArray) entry.getValue();
					for (JsonElement element : feedIds) {
						addFeedToFolder(folderName, element.getAsLong());
					}
				}
			}
		}
		return new FolderStructure(folderFeeds);
	}
	
	private void addFeedToFolder(String folderName, long feedId) {
		if (!folderFeeds.containsKey(folderName)) {
			List<Long> feedIds = new ArrayList<Long>();
			feedIds.add(feedId);
			folderFeeds.put(folderName, feedIds);
		} else {
			folderFeeds.get(folderName).add(feedId);
		}
	}
	
	

}
