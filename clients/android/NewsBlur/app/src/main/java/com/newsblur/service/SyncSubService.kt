package com.newsblur.service

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

abstract class SyncSubService(
    val delegate: SyncServiceDelegate,
) : SyncServiceDelegate by delegate {
    fun launchIn(scope: CoroutineScope): Job =
        scope.launch {
            execute()
        }

    protected abstract suspend fun execute()
}
