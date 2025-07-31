package com.newsblur.service

import android.content.Context
import com.newsblur.database.BlurDatabaseHelper
import com.newsblur.network.APIManager
import com.newsblur.network.domain.StoriesResponse
import com.newsblur.preference.PrefsRepo
import com.newsblur.util.FileCache
import com.newsblur.util.StateFilter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.plus

interface SyncServiceDelegate {

    val subJob: Job
    val subScope: CoroutineScope

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
}

internal class SyncServiceDelegateImpl(
        private val syncService: SyncService,
) : SyncServiceDelegate {

    override val subJob: Job = SupervisorJob(syncService.coroutineContext[Job])
    override val subScope: CoroutineScope = syncService + subJob

    override val dbHelper: BlurDatabaseHelper = syncService.dbHelper
    override val apiManager: APIManager = syncService.apiManager
    override val prefsRepo: PrefsRepo = syncService.prefsRepo
    override val storyImageCache: FileCache = syncService.storyImageCache
    override val iconCache: FileCache = syncService.iconCache
    override val thumbnailCache: FileCache = syncService.thumbnailCache
    override val context: Context = syncService.applicationContext

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
        syncService.insertStories(response, stateFilter)
    }

    override fun prefetchImages(response: StoriesResponse) {
        syncService.prefetchImages(response)
    }

    override fun isOrphanFeed(feedId: String): Boolean =
            syncService.isOrphanFeed(feedId)

    override fun isDisabledFeed(feedId: String): Boolean =
            syncService.isDisabledFeed(feedId)
}