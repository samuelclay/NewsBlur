package com.newsblur.network

import com.google.gson.Gson
import com.newsblur.network.domain.NewsBlurResponse
import org.junit.Assert.assertEquals
import org.junit.Test

class ClusterReadResponseTest {
    @Test
    fun markReadResponseRetainsServerExpandedClusterHashes() {
        val gson = Gson()
        val json = """{"code":1,"story_hashes":["1:parent","2:match","3:related"]}"""
        val response = gson.fromJson(json, NewsBlurResponse::class.java)

        // NewsBlurResponse must retain the server's authoritative cluster expansion for both read paths.
        assertEquals(gson.fromJson(json, com.google.gson.JsonObject::class.java)["story_hashes"],
            gson.toJsonTree(response).asJsonObject["story_hashes"])
    }
}
