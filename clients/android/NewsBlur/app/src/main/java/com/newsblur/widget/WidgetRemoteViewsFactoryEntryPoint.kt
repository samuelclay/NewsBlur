package com.newsblur.widget

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.di.IconLoader
import com.newsblur.di.ThumbnailLoader
import com.newsblur.network.StoryApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.ImageLoader
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@EntryPoint
@InstallIn(SingletonComponent::class)
interface WidgetRemoteViewsFactoryEntryPoint {
    fun dbHelper(): BlurDatabaseHelper

    fun prefRepository(): PrefsRepo

    fun storyApi(): StoryApi

    @IconLoader
    fun iconLoader(): ImageLoader

    @ThumbnailLoader
    fun thumbnailLoader(): ImageLoader
}
