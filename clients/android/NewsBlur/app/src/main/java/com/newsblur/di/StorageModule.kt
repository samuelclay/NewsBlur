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
    @StoryFileCache
    fun provideStoryCache(@ApplicationContext context: Context): FileCache =
            FileCache.asStoryImageCache(context)

    @Singleton
    @Provides
    @IconFileCache
    fun provideIconCache(@ApplicationContext context: Context): FileCache =
            FileCache.asIconCache(context)
}