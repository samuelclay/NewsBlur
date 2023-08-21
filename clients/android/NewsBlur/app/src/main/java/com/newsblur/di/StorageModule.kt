package com.newsblur.di

import android.content.Context
import android.content.SharedPreferences
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.util.FileCache
import com.newsblur.util.PrefConstants
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
class StorageModule {

    @Singleton
    @Provides
    fun provideSharedPrefs(@ApplicationContext context: Context): SharedPreferences =
            context.getSharedPreferences(PrefConstants.PREFERENCES, Context.MODE_PRIVATE)

    @Singleton
    @Provides
    fun provideBlurDbHelper(@ApplicationContext context: Context): BlurDatabaseHelper =
            BlurDatabaseHelper(context)

    @Singleton
    @Provides
    @StoryImageCache
    fun provideStoryCache(@ApplicationContext context: Context, @ImageOkHttpClient imageOkHttpClient: OkHttpClient): FileCache =
            FileCache.asStoryImageCache(context, imageOkHttpClient)

    @Singleton
    @Provides
    @IconFileCache
    fun provideIconCache(@ApplicationContext context: Context, @ImageOkHttpClient imageOkHttpClient: OkHttpClient): FileCache =
            FileCache.asIconCache(context, imageOkHttpClient)

    @Singleton
    @Provides
    @ThumbnailCache
    fun provideThumbnailCache(
            @ApplicationContext context: Context,
            @StoryImageCache storyImageCache: FileCache,
            @ImageOkHttpClient imageOkHttpClient: OkHttpClient,
    ): FileCache {
        val thumbnailCache = FileCache.asThumbnailCache(context, imageOkHttpClient)
        thumbnailCache.addChain(storyImageCache)
        return thumbnailCache
    }
}