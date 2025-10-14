package com.newsblur.di

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.reflect.TypeToken
import com.newsblur.domain.Classifier
import com.newsblur.domain.Story
import com.newsblur.network.AuthApi
import com.newsblur.network.AuthApiImpl
import com.newsblur.network.FeedApi
import com.newsblur.network.FeedApiImpl
import com.newsblur.network.FolderApi
import com.newsblur.network.FolderApiImpl
import com.newsblur.network.NetworkClient
import com.newsblur.network.NetworkClientImpl
import com.newsblur.network.StoryApi
import com.newsblur.network.StoryApiImpl
import com.newsblur.network.UserApi
import com.newsblur.network.UserApiImpl
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.serialization.BooleanTypeAdapter
import com.newsblur.serialization.ClassifierMapTypeAdapter
import com.newsblur.serialization.DateStringTypeAdapter
import com.newsblur.serialization.StoriesResponseTypeAdapter
import com.newsblur.serialization.StoryTypeAdapter
import com.newsblur.util.AppConstants
import com.newsblur.util.NetworkUtils
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import java.util.Date
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

private typealias CustomUserAgent = String

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Singleton
    @Provides
    fun provideGson(): Gson =
        GsonBuilder()
            .apply {
                registerTypeAdapter(Date::class.java, DateStringTypeAdapter())
                registerTypeAdapter(Boolean::class.java, BooleanTypeAdapter())
                registerTypeAdapter(Boolean::class.javaPrimitiveType, BooleanTypeAdapter())
                registerTypeAdapter(Story::class.java, StoryTypeAdapter())
                registerTypeAdapter(StoriesResponse::class.java, StoriesResponseTypeAdapter())
                registerTypeAdapter(object : TypeToken<Map<String?, Classifier?>?>() {}.type, ClassifierMapTypeAdapter())
            }.create()

    @Singleton
    @Provides
    @ApiOkHttpClient
    fun provideApiOkHttpClient(): OkHttpClient =
        OkHttpClient
            .Builder()
            .apply {
                connectTimeout(AppConstants.API_CONN_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                readTimeout(AppConstants.API_READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                followSslRedirects(true)
            }.build()

    @Singleton
    @Provides
    @ImageOkHttpClient
    fun provideImageOkHttpClient(): OkHttpClient =
        OkHttpClient
            .Builder()
            .apply {
                connectTimeout(AppConstants.IMAGE_PREFETCH_CONN_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                readTimeout(AppConstants.IMAGE_PREFETCH_READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
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
    fun provideNetworkClient(
        @ApplicationContext context: Context,
        @ApiOkHttpClient apiOkHttpClient: OkHttpClient,
        customUserAgent: CustomUserAgent,
        prefsRepo: PrefsRepo,
    ): NetworkClient =
        NetworkClientImpl(
            context = context,
            client = apiOkHttpClient,
            initialUserAgent = customUserAgent,
            prefsRepo = prefsRepo,
        )

    @Singleton
    @Provides
    fun provideAuthApi(
        gson: Gson,
        networkClient: NetworkClient,
        prefsRepo: PrefsRepo,
    ): AuthApi = AuthApiImpl(gson, networkClient, prefsRepo)

    @Singleton
    @Provides
    fun provideUserApi(
        @ApplicationContext context: Context,
        gson: Gson,
        networkClient: NetworkClient,
        prefsRepo: PrefsRepo,
    ): UserApi = UserApiImpl(context, gson, networkClient, prefsRepo)

    @Singleton
    @Provides
    fun provideFolderApi(
        gson: Gson,
        networkClient: NetworkClient,
    ): FolderApi = FolderApiImpl(gson, networkClient)

    @Singleton
    @Provides
    fun provideStoryApi(
        gson: Gson,
        networkClient: NetworkClient,
    ): StoryApi = StoryApiImpl(gson, networkClient)

    @Singleton
    @Provides
    fun provideFeedApi(
        gson: Gson,
        networkClient: NetworkClient,
    ): FeedApi = FeedApiImpl(gson, networkClient)
}
