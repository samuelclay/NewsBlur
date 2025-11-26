package com.newsblur.serialization

import com.google.gson.GsonBuilder
import com.google.gson.JsonArray
import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.newsblur.domain.Classifier
import com.newsblur.domain.Story
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.util.AppConstants.CLASSIFIERS_FEED_ID_PLACEHOLDER
import com.newsblur.util.Log
import java.lang.reflect.Type
import java.util.Date

class StoriesResponseTypeAdapter : JsonDeserializer<StoriesResponse> {
    private val innerGson =
        GsonBuilder()
            .apply {
                registerTypeAdapter(Date::class.java, DateStringTypeAdapter())
                registerTypeAdapter(Boolean::class.java, BooleanTypeAdapter())
                registerTypeAdapter(Boolean::class.javaPrimitiveType, BooleanTypeAdapter())
                registerTypeAdapter(Story::class.java, StoryTypeAdapter())
            }.create()

    override fun deserialize(
        json: JsonElement,
        typeOfT: Type?,
        context: JsonDeserializationContext,
    ): StoriesResponse {
        if (json.isJsonObject) {
            val jsonObject = json.asJsonObject

            normalizeFeeds(jsonObject)

            val classifiersMap = parseClassifiers(jsonObject, context)

            val result: StoriesResponse = innerGson.fromJson(jsonObject, StoriesResponse::class.java)

            if (classifiersMap != null) {
                result.classifiers = classifiersMap
            }

            return result
        }

        return context.deserialize(json, StoriesResponse::class.java)
    }

    private fun normalizeFeeds(root: JsonObject) {
        val feedsElement = root.get(FEEDS) ?: return

        if (feedsElement.isJsonObject) {
            val feedsArray = JsonArray()
            feedsElement.asJsonObject.entrySet().forEach { (_, value) ->
                feedsArray.add(value)
            }
            root.add(FEEDS, feedsArray)
        }
    }

    private fun parseClassifiers(
        root: JsonObject,
        context: JsonDeserializationContext,
    ): Map<String, Classifier>? {
        val classifiersElement = root.get(CLASSIFIERS) ?: return null
        root.remove(CLASSIFIERS)

        val result = mutableMapOf<String, Classifier>()

        if (classifiersElement.isJsonObject) {
            val obj = classifiersElement.asJsonObject

            val looksLikeBareClassifier = obj.has(AUTHORS)

            if (looksLikeBareClassifier) {
                // single classifier, synthesize a fake feed id
                val classifier: Classifier = context.deserialize(obj, Classifier::class.java)
                result[CLASSIFIERS_FEED_ID_PLACEHOLDER] = classifier
            } else {
                // map of feedId -> classifier
                for ((key, value) in obj.entrySet()) {
                    if (!value.isJsonObject) continue
                    val classifier: Classifier = context.deserialize(value, Classifier::class.java)
                    result[key] = classifier
                }
            }
        } else {
            Log.e("StoriesResponseTypeAdapter", "Expected 'classifiers' to be an object, got: $classifiersElement")
        }

        return result
    }

    companion object {
        private const val CLASSIFIERS = "classifiers"
        private const val FEEDS = "feeds"
        private const val AUTHORS = "authors"
    }
}
