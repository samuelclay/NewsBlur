package com.newsblur.di

import android.content.Context
import com.newsblur.util.FileCache
import com.newsblur.util.ImageLoader
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
class ImageModule {

    @Singleton
    @Provides
    @IconLoader
    fun provideIconLoader(@ApplicationContext context: Context): ImageLoader =
            ImageLoader.asIconLoader(context)

    @Singleton
    @Provides
    @ThumbnailLoader
    fun provideThumbnailLoader(
            @ApplicationContext context: Context,
            @StoryFileCache fileCache: FileCache,
    ): ImageLoader = ImageLoader.asThumbnailLoader(context, fileCache)
}