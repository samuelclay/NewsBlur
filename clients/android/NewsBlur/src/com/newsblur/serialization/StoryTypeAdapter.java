package com.newsblur.serialization;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonParseException;

import com.newsblur.domain.Story;
import com.newsblur.util.UIUtils;

import java.lang.reflect.Type;
import java.util.Date;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Created by mark on 15/03/2014.
 */
public class StoryTypeAdapter implements JsonDeserializer<Story> {

    private Gson gson;

    // any characters we don't want in the short description, such as newlines or placeholders
    private final static Pattern ShortContentExcludes = Pattern.compile("[\\uFFFC\\u000A\\u000B\\u000C\\u000D]");

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
        
        // populate the shortContent field
        if (story.content != null) {
            CharSequence parsed = UIUtils.fromHtml(story.content);
            int length = 200;
            if (parsed.length() < 200) { length = parsed.length(); }
            story.shortContent = parsed.subSequence(0, length).toString();
            Matcher m = ShortContentExcludes .matcher(story.shortContent);
            story.shortContent = m.replaceAll(" ").trim();
        }
        
        return story;
    }
}
