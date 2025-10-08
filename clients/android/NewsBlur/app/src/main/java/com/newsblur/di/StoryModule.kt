package com.newsblur.di

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.preference.PrefsRepo
import com.newsblur.repository.StoryRepository
import com.newsblur.repository.StoryRepositoryImpl
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
class StoryModule {

    @Singleton
    @Provides
    fun provideStoryRepository(
            prefsRepo: PrefsRepo,
            dbHelper: BlurDatabaseHelper,
    ): StoryRepository = StoryRepositoryImpl(
            prefsRepo,
            dbHelper,
    )
}