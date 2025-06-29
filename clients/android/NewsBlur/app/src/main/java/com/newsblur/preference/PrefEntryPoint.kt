package com.newsblur.preference

import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.components.ActivityComponent


@EntryPoint
@InstallIn(ActivityComponent::class)
interface PrefsEntryPoint {
    val prefsRepository: PrefsRepo
}