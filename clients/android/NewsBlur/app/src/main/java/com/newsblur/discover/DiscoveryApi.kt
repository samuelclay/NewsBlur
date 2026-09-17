package com.newsblur.discover

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.APIConstants
import com.newsblur.network.NetworkClient
import java.io.IOException
import javax.inject.Inject

class DiscoveryApi @Inject constructor(private val client: NetworkClient) {
    suspend fun request(path: String, params: Map<String, String> = emptyMap(), post: Boolean = false): JsonObject {
        val values = ValueMultimap().apply { params.forEach { (key, value) -> put(key, value) } }
        val url = APIConstants.buildUrl(path)
        val response = if (post) client.post(url, values) else client.get(url, values)
        if (response.isError || response.responseBody.isNullOrBlank()) {
            throw IOException("Couldn’t reach this feature. Check your connection and try again. Your server may need an update.")
        }
        val json = JsonParser.parseString(response.responseBody).asJsonObject
        val waiting = path == "/webfeed/status" && json.string("status") == "unknown"
        if (json.number("code") < 0 && !waiting) {
            throw IOException(json.string("message").ifBlank { json.string("error").ifBlank { "The request failed. Please try again." } })
        }
        return json
    }
}

internal fun JsonObject.string(key: String): String = get(key)?.takeIf { it.isJsonPrimitive }?.asString.orEmpty()
internal fun JsonObject.number(key: String): Int = string(key).toIntOrNull() ?: 0
internal fun JsonObject.objects(key: String): List<JsonObject> = get(key)?.takeIf { it.isJsonArray }?.asJsonArray?.filter { it.isJsonObject }?.map { it.asJsonObject }.orEmpty()
internal fun JsonObject.obj(key: String): JsonObject? = get(key)?.takeIf { it.isJsonObject }?.asJsonObject
