package com.newsblur.service

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

abstract class SyncSubService(
        val delegate: SyncServiceDelegate
) : SyncServiceDelegate by delegate {

    fun start(scope: CoroutineScope) {
        scope.launch {
            execute()
        }
    }

    protected abstract suspend fun execute()
}