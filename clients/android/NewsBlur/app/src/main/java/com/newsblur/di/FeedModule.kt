package com.newsblur.di

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.network.FeedApi
import com.newsblur.network.FolderApi
import com.newsblur.network.UserApi
import com.newsblur.preference.PrefsRepo
import com.newsblur.repository.FeedRepository
import com.newsblur.repository.FeedRepositoryImpl
import com.newsblur.service.SyncServiceState
import com.newsblur.util.FeedUtils
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
class FeedModule {
    @Singleton
    @Provides
    fun provideFeedUtils(
        dbHelper: BlurDatabaseHelper,
        folderApi: FolderApi,
        prefsRepo: PrefsRepo,
        syncServiceState: SyncServiceState,
    ) = FeedUtils(dbHelper, folderApi, prefsRepo, syncServiceState)

    @Singleton
    @Provides
    fun provideFeedRepository(
        userApi: UserApi,
        feedApi: FeedApi,
        dbHelper: BlurDatabaseHelper,
    ): FeedRepository =
        FeedRepositoryImpl(
            userApi,
            feedApi,
            dbHelper,
        )
}
