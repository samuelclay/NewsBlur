package com.newsblur.di

import com.newsblur.service.DefaultSyncServiceState
import com.newsblur.service.SyncServiceState
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class SyncServiceModule {
    @Binds
    @Singleton
    abstract fun bindSyncServiceState(
            impl: DefaultSyncServiceState
    ): SyncServiceState
}