package com.newsblur.serialization

import com.google.gson.*
import com.newsblur.domain.Story
import com.newsblur.network.domain.StoriesResponse
import java.lang.reflect.Type
import java.util.*

class StoriesResponseTypeAdapter : JsonDeserializer<StoriesResponse> {

    private val gson = GsonBuilder().apply {
        registerTypeAdapter(Date::class.java, DateStringTypeAdapter())
        registerTypeAdapter(Boolean::class.java, BooleanTypeAdapter())
        registerTypeAdapter(Boolean::class.javaPrimitiveType, BooleanTypeAdapter())
        registerTypeAdapter(Story::class.java, StoryTypeAdapter())
    }.create()

    override fun deserialize(json: JsonElement, typeOfT: Type?, context: JsonDeserializationContext?): StoriesResponse {
        if (json.isJsonObject) {
            val jsonObject = json.asJsonObject
            val feedsElement: JsonElement? = jsonObject.get("feeds")

            // extract values when feeds is a map
            if (feedsElement != null && feedsElement.isJsonObject) {
                val feedsArray = JsonArray()
                val feedsJsonObj = feedsElement.asJsonObject
                feedsJsonObj.entrySet().forEach {
                    feedsArray.add(it.value)
                    feedsJsonObj.remove(it.key)
                }

                jsonObject.add("feeds", feedsArray)
            }
        }

        return gson.fromJson(json, StoriesResponse::class.java)
    }
}