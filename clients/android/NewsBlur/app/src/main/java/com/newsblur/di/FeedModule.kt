package com.newsblur.di

import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.network.APIManager
import com.newsblur.network.FolderApi
import com.newsblur.network.UserApi
import com.newsblur.preference.PrefsRepo
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
            apiManager: APIManager,
            userApi: UserApi,
            folderApi: FolderApi,
            prefsRepo: PrefsRepo
    ) = FeedUtils(dbHelper, apiManager, userApi, folderApi, prefsRepo)
}