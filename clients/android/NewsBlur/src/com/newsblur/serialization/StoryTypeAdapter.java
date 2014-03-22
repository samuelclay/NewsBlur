package com.newsblur.serialization;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonParseException;
import com.newsblur.domain.Story;

import java.lang.reflect.Type;
import java.util.Date;

/**
 * Created by mark on 15/03/2014.
 */
public class StoryTypeAdapter implements JsonDeserializer<Story> {

    private Gson gson;

    public StoryTypeAdapter() {
        this.gson = new GsonBuilder()
                .registerTypeAdapter(Date.class, new DateStringTypeAdapter())
                .registerTypeAdapter(Boolean.class, new BooleanTypeAdapter())
                .registerTypeAdapter(boolean.class, new BooleanTypeAdapter())
                .create();
    }

    @Override
    public Story deserialize(JsonElement jsonElement, Type type, JsonDeserializationContext jsonDeserializationContext) throws JsonParseException {
        Story story = gson.fromJson(jsonElement, Story.class);
        // Convert story_timestamp to milliseconds
        story.timestamp = story.timestamp * 1000;
        return story;
    }
}
