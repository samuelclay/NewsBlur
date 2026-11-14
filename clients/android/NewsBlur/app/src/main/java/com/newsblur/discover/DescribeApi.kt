package com.newsblur.discover

import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.newsblur.domain.ValueMultimap
import com.newsblur.network.APIConstants
import com.newsblur.network.NetworkClient
import java.io.IOException
import javax.inject.Inject

// DescribeApi.kt: the four endpoints of apps/describe/views.py, mounted under /discover/describe/.
class DescribeApi
    @Inject
    constructor(
        private val client: NetworkClient,
    ) {
        suspend fun start(
            prompt: String,
            searchId: String?,
            requestId: String,
        ): DescribeStart {
            val params = mutableMapOf("prompt" to prompt, "request_id" to requestId)
            if (!searchId.isNullOrBlank()) params["search_id"] = searchId
            return DescribeStart.parse(request("/discover/describe/start", params, post = true))
        }

        suspend fun status(searchId: String): DescribeSearch {
            val json = request("/discover/describe/status", mapOf("search_id" to searchId))
            return json.obj("search")?.let(DescribeSearch::parse) ?: throw DescribeRequestException(json.string("message"))
        }

        suspend fun history(): DescribeHistory {
            val json = request("/discover/describe/history")
            if (json.number("code") <= 0) throw DescribeRequestException(json.string("message"))
            return DescribeHistory(json.objects("searches").mapNotNull(DescribeSummary::parse), DescribeUsage.parse(json.obj("usage")))
        }

        suspend fun delete(searchId: String): List<DescribeSummary> {
            val json = request("/discover/describe/delete", mapOf("search_id" to searchId), post = true)
            if (json.number("code") <= 0) throw DescribeRequestException(json.string("message"))
            return json.objects("searches").mapNotNull(DescribeSummary::parse)
        }

        // DescribeApi.kt: a failed request carries no message; a `code: -1` reply carries the server's localized one.
        private suspend fun request(
            path: String,
            params: Map<String, String> = emptyMap(),
            post: Boolean = false,
        ): JsonObject {
            val values = ValueMultimap().apply { params.forEach { (key, value) -> put(key, value) } }
            val url = APIConstants.buildUrl(path)
            val response = if (post) client.post(url, values) else client.get(url, values)
            if (response.isError || response.responseBody.isNullOrBlank()) throw DescribeRequestException(null)
            return JsonParser.parseString(response.responseBody).asJsonObject
        }
    }

class DescribeRequestException(
    val serverMessage: String?,
) : IOException(serverMessage)
