package com.newsblur.di

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.network.FeedApi
import com.newsblur.network.FolderApi
import com.newsblur.network.UserApi
import com.newsblur.preference.PrefsRepo
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
            feedApi: FeedApi,
            userApi: UserApi,
            folderApi: FolderApi,
            prefsRepo: PrefsRepo,
            syncServiceState: SyncServiceState,
    ) = FeedUtils(dbHelper, feedApi, userApi, folderApi, prefsRepo, syncServiceState)
}