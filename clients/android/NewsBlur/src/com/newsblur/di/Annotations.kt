package com.newsblur.di

import javax.inject.Qualifier

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class StoryFileCache

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class IconFileCache

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class IconLoader

@Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class ThumbnailLoader


