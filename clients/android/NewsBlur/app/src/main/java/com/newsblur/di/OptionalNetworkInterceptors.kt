package com.newsblur.di

import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dagger.multibindings.Multibinds
import okhttp3.Interceptor

/** OptionalNetworkInterceptors.kt is empty in production; isolated capture builds contribute their fixture. */
@Module
@InstallIn(SingletonComponent::class)
interface OptionalNetworkInterceptors {
    @Multibinds
    fun interceptors(): Set<Interceptor>
}
