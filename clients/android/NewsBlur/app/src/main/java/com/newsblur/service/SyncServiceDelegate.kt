package com.newsblur.service

import android.content.Context
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.network.APIManager
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.FileCache
import com.newsblur.util.Log
import com.newsblur.util.StateFilter

interface SyncServiceDelegate {

    val dbHelper: BlurDatabaseHelper
    val apiManager: APIManager
    val prefsRepo: PrefsRepo
    val storyImageCache: FileCache
    val iconCache: FileCache
    val thumbnailCache: FileCache
    val context: Context

    fun sendSyncUpdate(update: Int)
    fun pushNotifications()
    fun addImageUrlToPrefetch(url: String?)
    fun insertStories(response: StoriesResponse, stateFilter: StateFilter)
    fun prefetchImages(response: StoriesResponse)
    fun isOrphanFeed(feedId: String): Boolean
    fun isDisabledFeed(feedId: String): Boolean
    fun setServiceState(state: ServiceState)
    fun setServiceStateIdleIf(state: ServiceState)
}

internal class SyncServiceDelegateImpl(
        private val syncService: SyncService,
) : SyncServiceDelegate {

    override val dbHelper: BlurDatabaseHelper get() = syncService.dbHelper
    override val apiManager: APIManager get() = syncService.apiManager
    override val prefsRepo: PrefsRepo get() = syncService.prefsRepo
    override val storyImageCache: FileCache get() = syncService.storyImageCache
    override val iconCache: FileCache get() = syncService.iconCache
    override val thumbnailCache: FileCache get() = syncService.thumbnailCache
    override val context: Context get() = syncService.applicationContext

    override fun sendSyncUpdate(update: Int) {
        syncService.sendSyncUpdate(update)
    }

    override fun pushNotifications() {
        syncService.pushNotifications()
    }

    override fun addImageUrlToPrefetch(url: String?) {
        syncService.addImageUrlToPrefetch(url)
    }

    override fun insertStories(response: StoriesResponse, stateFilter: StateFilter) {
        Log.d(SyncService::class.java.name, "got stories from sub sync: " + response.stories.size)
        dbHelper.insertStories(response, stateFilter, false)
    }

    override fun prefetchImages(response: StoriesResponse) {
        syncService.prefetchImages(response)
    }

    override fun isOrphanFeed(feedId: String): Boolean = syncService.isOrphanFeed(feedId)

    override fun isDisabledFeed(feedId: String): Boolean = syncService.isDisabledFeed(feedId)

    override fun setServiceState(state: ServiceState) {
        syncService.syncServiceState.setServiceState(state)
    }

    override fun setServiceStateIdleIf(state: ServiceState) {
        if (syncService.syncServiceState == state) {
            syncService.syncServiceState.setServiceState(ServiceState.Idle)
        }
    }
}