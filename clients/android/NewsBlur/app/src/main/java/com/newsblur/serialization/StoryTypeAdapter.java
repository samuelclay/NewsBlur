package com.newsblur.serialization;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonParseException;

import com.newsblur.domain.Story;
import com.newsblur.network.APIConstants;
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
    private final static Pattern httpSniff = Pattern.compile("(?:http):\\//");

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
        story.starredTimestamp = story.starredTimestamp * 1000;

        // replace http image urls with https
        if (httpSniff.matcher(story.content).find() && story.secureImageUrls != null && story.secureImageUrls.size() > 0) {
            for (String url : story.secureImageUrls.keySet()) {
                if (httpSniff.matcher(url).find()) {
                    String secureUrl = story.secureImageUrls.get(url);
                    if (APIConstants.isCustomServer() && secureUrl != null && !secureUrl.startsWith("http")) {
                        secureUrl = APIConstants.buildUrl(APIConstants.PATH_IMAGE_PROXY + secureUrl);
                    }
                    story.content = story.content.replace(url, secureUrl);
                }
            }
        }
        
        // populate the shortContent field
        if (story.content != null) {
            CharSequence parsed = UIUtils.fromHtml(story.content);
            int length = 400;
            if (parsed.length() < length) { length = parsed.length(); }
            story.shortContent = parsed.subSequence(0, length).toString();
            Matcher m = ShortContentExcludes .matcher(story.shortContent);
            story.shortContent = m.replaceAll(" ").trim();
        }
        
        return story;
    }
}
