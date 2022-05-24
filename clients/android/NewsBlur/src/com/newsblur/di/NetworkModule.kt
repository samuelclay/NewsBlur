package com.newsblur.di

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.TypeAdapterFactory
import com.google.gson.reflect.TypeToken
import com.newsblur.domain.Classifier
import com.newsblur.domain.Feed
import com.newsblur.domain.Story
import com.newsblur.network.APIConstants
import com.newsblur.network.APIManager
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.serialization.*
import com.newsblur.util.AppConstants
import com.newsblur.util.NetworkUtils
import com.newsblur.util.PrefConstants
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import java.util.*
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

private typealias CustomUserAgent = String

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Singleton
    @Provides
    fun provideGson(): Gson = GsonBuilder().apply {
        registerTypeAdapter(Date::class.java, DateStringTypeAdapter())
        registerTypeAdapter(Boolean::class.java, BooleanTypeAdapter())
        registerTypeAdapter(Boolean::class.javaPrimitiveType, BooleanTypeAdapter())
        registerTypeAdapter(Story::class.java, StoryTypeAdapter())
        registerTypeAdapter(StoriesResponse::class.java, StoriesResponseTypeAdapter())
        registerTypeAdapter(object : TypeToken<Map<String?, Classifier?>?>() {}.type, ClassifierMapTypeAdapter())
    }.create()

    @Singleton
    @Provides
    fun provideOkHttpClient(): OkHttpClient = OkHttpClient.Builder().apply {
        connectTimeout(AppConstants.API_CONN_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        readTimeout(AppConstants.API_READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        followSslRedirects(true)
    }.build()

    @Singleton
    @Provides
    fun provideCustomUserAgent(sharedPreferences: SharedPreferences): CustomUserAgent {
        val appVersion: String = sharedPreferences.getString(AppConstants.LAST_APP_VERSION, "unknown_version")!!
        return NetworkUtils.getCustomUserAgent(appVersion)
    }

    @Singleton
    @Provides
    fun provideApiManager(
            @ApplicationContext context: Context,
            customUserAgent: CustomUserAgent,
            gson: Gson,
            okHttpClient: OkHttpClient): APIManager =
            APIManager(context,
                    gson,
                    customUserAgent,
                    okHttpClient)
}