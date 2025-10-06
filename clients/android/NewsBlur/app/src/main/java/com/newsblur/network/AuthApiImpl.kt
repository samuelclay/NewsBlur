package com.newsblur.network

import android.content.ContentValues
import com.google.gson.Gson
import com.newsblur.network.domain.LoginResponse
import com.newsblur.network.domain.RegisterResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.Log
import okhttp3.OkHttpClient
import okhttp3.Request
import okio.IOException

class AuthApiImpl(
        private val gson: Gson,
        private val networkClient: NetworkClient,
        private val prefsRepo: PrefsRepo,
) : AuthApi {

    override suspend fun login(username: String, password: String): LoginResponse {
        Log.i(this.javaClass.name, "Calling login API")
        val values = ContentValues().apply {
            put(APIConstants.PARAMETER_USERNAME, username)
            put(APIConstants.PARAMETER_PASSWORD, password)
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_LOGIN)

        val response: APIResponse = networkClient.post(urlString, values)
        val loginResponse = response.getLoginResponse(gson)
        if (!response.isError) {
            prefsRepo.saveLogin(username, response.cookie)
        }
        return loginResponse
    }

    override suspend fun loginAs(username: String): Boolean {
        val values = ContentValues().apply {
            put(APIConstants.PARAMETER_USER, username)
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_LOGINAS) + "?" + networkClient.builderGetParametersString(values)
        Log.i(this.javaClass.name, "Doing superuser swap: $urlString")
        // This API returns a redirect that means the call worked, but we do not want to follow it.  To
        // just get the cookie from the 302 and stop, we directly use a one-off OkHttpClient.
        val requestBuilder = Request.Builder().url(urlString)
        networkClient.addCookieHeader(requestBuilder)
        val noredirHttpClient = OkHttpClient.Builder()
                .followRedirects(false)
                .build()
        try {
            val response = noredirHttpClient.newCall(requestBuilder.build()).execute()
            if (!response.isRedirect) return false.also { response.close() }
            val newCookie = response.header("Set-Cookie")
            prefsRepo.saveLogin(username, newCookie)
            response.close()
        } catch (_: IOException) {
            return false
        }
        return false
    }

    override suspend fun signup(username: String, password: String, email: String): RegisterResponse {
        val values = ContentValues().apply {
            put(APIConstants.PARAMETER_USERNAME, username)
            put(APIConstants.PARAMETER_PASSWORD, password)
            put(APIConstants.PARAMETER_EMAIL, email)
        }
        val urlString = APIConstants.buildUrl(APIConstants.PATH_SIGNUP)

        val response: APIResponse = networkClient.post(urlString, values)
        val registerResponse = response.getRegisterResponse(gson)
        if (!response.isError) {
            prefsRepo.saveLogin(username, response.cookie)
        }
        return registerResponse
    }
}