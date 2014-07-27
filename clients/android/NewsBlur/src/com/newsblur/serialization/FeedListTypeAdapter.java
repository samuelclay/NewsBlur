package com.newsblur.serialization;

import com.google.gson.GsonBuilder;
import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonParseException;
import com.newsblur.domain.Feed;

import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

/**
 * Special handler for the "feeds" field that appears in API responses and is sometimes
 * a list and sometimes a set and sometimes null and sometimes an empty object.
 */
public class FeedListTypeAdapter implements JsonDeserializer<List<Feed>> {

    @Override
    public List<Feed> deserialize(JsonElement jsonElement, Type type, JsonDeserializationContext jsonDeserializationContext) throws JsonParseException {

        List<Feed> result = new ArrayList<Feed>();

        if (jsonElement.isJsonObject()) {
            Feed feed = (Feed) jsonDeserializationContext.deserialize(jsonElement, Feed.class);
            result.add(feed);
        } else if (jsonElement.isJsonArray()) {
            for (JsonElement arrayMember : jsonElement.getAsJsonArray()) {
                Feed feed = (Feed) jsonDeserializationContext.deserialize(jsonElement, Feed.class);
                result.add(feed);
            } 
        }

        return result;
    }
}
