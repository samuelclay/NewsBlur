package com.newsblur.di

import javax.inject.Qualifier

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class StoryImageCache

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class IconFileCache

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class ThumbnailCache

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class IconLoader

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class ThumbnailLoader

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class ApiOkHttpClient

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class ImageOkHttpClient


