package com.newsblur.serialization;

import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.newsblur.domain.Classifier;

import java.lang.reflect.Type;
import java.util.HashMap;
import java.util.Map;

/**
 * Special handler for the "classifiers" field that appears in API responses that is supposed to be
 * a map of feed IDs to classifier objects, but sometimes is just a bare object with no feed ID if
 * the API thinks we can imply it from context. This adapter re-inserts a -1 feed ID when the latter
 * happens so that we don't have to write two different bindings for responses to different requests.
 */
public class ClassifierMapTypeAdapter implements JsonDeserializer<Map<String,Classifier>> {

    @Override
    public Map<String,Classifier> deserialize(JsonElement jsonElement, Type type, JsonDeserializationContext jsonDeserializationContext) throws JsonParseException {

        Map<String,Classifier> result = new HashMap<String,Classifier>();

        if (jsonElement.isJsonObject()) {
            JsonObject o = jsonElement.getAsJsonObject();
            if (o.get("authors") != null) { // this is our hint that this is a bare classifiers object
                Classifier c = (Classifier) jsonDeserializationContext.deserialize(jsonElement, Classifier.class);
                result.put( "-1", c);
            } else { // otherwise, we have a map of IDs to classifiers
                for (Map.Entry<String, JsonElement> entry : o.entrySet()) {
                    Classifier c = (Classifier) jsonDeserializationContext.deserialize(entry.getValue(), Classifier.class);
                    result.put(entry.getKey(), c);
                }
            }
        } else {
            throw new IllegalStateException("classifiers object is not an object");
        }

        return result;
    }
}
