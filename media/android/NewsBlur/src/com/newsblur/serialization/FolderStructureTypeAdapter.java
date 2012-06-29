package com.newsblur.serialization;

import java.lang.reflect.Type;
import java.util.Iterator;

import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonParseException;
import com.newsblur.domain.FolderStructure;

public class FolderStructureTypeAdapter implements JsonDeserializer<FolderStructure> {

	@Override
	public FolderStructure deserialize(JsonElement jsonElement, Type type, JsonDeserializationContext context) throws JsonParseException {
		Iterator<JsonElement> jsonFolderArray = jsonElement.getAsJsonArray().iterator();
		
		FolderStructure folderStructure = new FolderStructure();
		//		while (jsonFolderArray.hasNext()) {
		//			if (jsonFolderArray.next().isJsonPrimitive()) {
		//				folderStructure.
		//			}
		//		}
		// TODO: Correctly parse out primitives / folder list correctly
		
        return folderStructure;
		
	}

}
