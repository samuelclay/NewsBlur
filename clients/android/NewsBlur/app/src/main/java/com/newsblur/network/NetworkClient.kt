package com.newsblur.network

import android.content.ContentValues
import com.newsblur.domain.ValueMultimap
import okhttp3.Request
import okhttp3.RequestBody

interface NetworkClient {

    fun get(urlString: String): APIResponse

    fun get(urlString: String, values: ContentValues): APIResponse

    fun get(urlString: String, valueMap: ValueMultimap): APIResponse

    fun post(urlString: String, formBody: RequestBody): APIResponse

    fun post(urlString: String, values: ContentValues): APIResponse

    fun post(urlString: String, valueMap: ValueMultimap): APIResponse

    fun updateCustomUserAgent(customUserAgent: String)

    fun addCookieHeader(requestBuilder: Request.Builder)

    fun builderGetParametersString(values: ContentValues): String
}